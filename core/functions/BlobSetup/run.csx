//
// Copyright  Microsoft Corporation ("Microsoft").
//
// Microsoft grants you the right to use this software in accordance with your subscription agreement, if any, to use software 
// provided for use with Microsoft Azure ("Subscription Agreement").  All software is licensed, not sold.  
// 
// If you do not have a Subscription Agreement, or at your option if you so choose, Microsoft grants you a nonexclusive, perpetual, 
// royalty-free right to use and modify this software solely for your internal business purposes in connection with Microsoft Azure 
// and other Microsoft products, including but not limited to, Microsoft R Open, Microsoft R Server, and Microsoft SQL Server.  
// 
// Unless otherwise stated in your Subscription Agreement, the following applies.  THIS SOFTWARE IS PROVIDED "AS IS" WITHOUT 
// WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL MICROSOFT OR ITS LICENSORS BE LIABLE 
// FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED 
// TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) 
// HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
// NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THE SAMPLE CODE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.
//

#load "..\CiqsHelpers\All.csx"

using System;
using System.Collections.Generic;
using System.IO;
using System.Threading;
using System.Diagnostics;
using Microsoft.WindowsAzure.Storage;
using Microsoft.WindowsAzure.Storage.Auth;
using Microsoft.WindowsAzure.Storage.Blob;

public static async Task<object> Run(HttpRequestMessage req, TraceWriter log)
{
    var parametersReader = await CiqsInputParametersReader.FromHttpRequestMessage(req);

    string storageAccountName = parametersReader.GetParameter<string>("storageAccountName");
    string storageAccountKey = parametersReader.GetParameter<string>("storageAccountKey");
    string scriptBundlePath = parametersReader.GetParameter<string>("scriptBundlePath");
    string pricingResourceContainerName = parametersReader.GetParameter<string>("pricingResourceContainerName");
    string adfLoggingContainerName = parametersReader.GetParameter<string>("adfLoggingContainerName");
    string adfPricingDataContainerName = parametersReader.GetParameter<string>("adfPricingDataContainerName");
    int blobCopyTimeoutMs = 300000;

    var storageCredentials = new StorageCredentials(storageAccountName, storageAccountKey);
    var storageAccount = new CloudStorageAccount(storageCredentials, true);
    var storageClient = storageAccount.CreateCloudBlobClient();

    // Create containers
    var pricingResourceContainer = storageClient.GetContainerReference(pricingResourceContainerName);
    pricingResourceContainer.CreateIfNotExists(BlobContainerPublicAccessType.Off);
    log.Info($"Created container {pricingResourceContainerName}");

    var adfContainer = storageClient.GetContainerReference(adfLoggingContainerName);
    adfContainer.CreateIfNotExists(BlobContainerPublicAccessType.Off);
    log.Info($"Created container {adfLoggingContainerName}");

    adfContainer = storageClient.GetContainerReference(adfPricingDataContainerName);
    adfContainer.CreateIfNotExists(BlobContainerPublicAccessType.Off);
    log.Info($"Created container {adfPricingDataContainerName}");

    // Copy script bundle to container
    var scriptBundleUri = new Uri(scriptBundlePath);
    string blobName = Path.GetFileName(scriptBundleUri.LocalPath);

    log.Info($"Copying {scriptBundlePath} as {blobName}");

    CloudBlockBlob target = pricingResourceContainer.GetBlockBlobReference(blobName);
    target.StartCopy(scriptBundleUri);

    Stopwatch sw = new Stopwatch();
    sw.Start();
    while (target.CopyState.Status == CopyStatus.Pending)
    {
        target.FetchAttributes();
        Thread.Sleep(5000);
        if(sw.ElapsedMilliseconds > blobCopyTimeoutMs)
        {
            throw new TimeoutException($"Copy operation for {blobName} timed out.");
        }
    }

    if (target.CopyState.Status == CopyStatus.Success)
    {
        log.Info($"Done copying {scriptBundlePath} as {blobName}");
    }
    else
    {
        throw new Exception($"Error copying {scriptBundlePath} as {blobName}");
    }

    return new
    {
        pricingResourceContainerName = pricingResourceContainerName,
        adfLoggingContainerName = adfLoggingContainerName,
        adfPricingDataContainerName = adfPricingDataContainerName,
        scriptBundleUri = target.Uri.ToString()
    };
}
