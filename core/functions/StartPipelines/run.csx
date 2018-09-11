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

using System.IO;
using System.Threading;
using System;
using System.Globalization;
using System.Net;
using System.Configuration;
using Microsoft.Azure;
using Microsoft.Azure.Management.DataFactories.Common.Models;
using Microsoft.Azure.Management.DataFactories.Core;

public static async Task<object> Run(HttpRequestMessage req, TraceWriter log)
{
    var parametersReader = await CiqsInputParametersReader.FromHttpRequestMessage(req);

    string[] pipelineNames = { "ConfigureServices_Pipeline", "Pricing_Pipeline", "SuggestionPipeline" };

    const string ResourceManagerEndpoint = "https://management.azure.com/";
    string subscriptionId = parametersReader.GetParameter<string>("subscriptionId");
    string dataFactoryName = parametersReader.GetParameter<string>("dataFactoryName");
    string resourceGroupName = parametersReader.GetParameter<string>("resourceGroupName");
    string authorizationToken = parametersReader.GetParameter<string>("authorizationToken");
    int pipelineActiveWeeks = parametersReader.GetParameter<int>("pipelineActiveWeeks");

    var dfClient = new DataFactoryManagementClient(new TokenCloudCredentials(subscriptionId, authorizationToken),
                                                   new Uri(ResourceManagerEndpoint));
    log.Info($"dfClient: {dfClient.ToString()}");

    // start all pipelines as of today to avoid activity race conditions
    var nowDateTime = DateTime.UtcNow;    

    var nowDate = nowDateTime.Date;
    var currentWeekStart = nowDate.AddDays(-1 * (int)nowDate.DayOfWeek);
    var pipelineStartDate = currentWeekStart.AddDays(-7);
    if (nowDateTime.DayOfWeek== DayOfWeek.Saturday && nowDateTime.Hour==23 && nowDateTime.Minute>=30)
    {
        pipelineStartDate = currentWeekStart.AddDays(7);
    }

    var pipelineStartString = pipelineStartDate.ToString("s", CultureInfo.InvariantCulture);
    var pipelineEndString = pipelineStartDate.AddDays(pipelineActiveWeeks * 7).ToString("s", CultureInfo.InvariantCulture);

    foreach (string pname in pipelineNames)
    {
        // Activate the pipeline
        dfClient.Pipelines.SetActivePeriod(resourceGroupName,
                                           dataFactoryName,
                                           pname,
                                           new PipelineSetActivePeriodParameters(pipelineStartString, pipelineEndString));

        dfClient.Pipelines.Resume(resourceGroupName,
                                  dataFactoryName,
                                  pname);
    }

    return new
    {
        started = true
    };
}
