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

#r "Newtonsoft.Json"
#load "..\CiqsHelpers\All.csx"

using System;
using System.Globalization;
using System.Collections.Generic;
using System.IO;
using System.Threading;
using System.Net.Http;
using System.Net.Http.Headers;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using Microsoft.Azure;

public class MlServiceCredentials
{ 
    public string EndpointUrl { get; set; }

    public string ApiKey { get; set; }
}

public static async Task<object> Run(HttpRequestMessage req, TraceWriter log)
{
    var parametersReader = await CiqsInputParametersReader.FromHttpRequestMessage(req);

    string subscriptionId = parametersReader.GetParameter<string>("subscriptionId");
    string resourceGroupName = parametersReader.GetParameter<string>("resourceGroupName");
    string authorizationToken = parametersReader.GetParameter<string>("authorizationToken");
    string buildModelServiceName = parametersReader.GetParameter<string>("buildModelServiceName");
    string fcastServiceName = parametersReader.GetParameter<string>("fcastServiceName");
    string elastServiceName = parametersReader.GetParameter<string>("elastServiceName");
    string crossElastServiceName = parametersReader.GetParameter<string>("crossElastServiceName");
    string apiVersion = parametersReader.GetParameter<string>("mlWsApiVersion");

    var azureCredentials = new TokenCloudCredentials(subscriptionId, authorizationToken);
    var serviceList = new string[] { buildModelServiceName, fcastServiceName, elastServiceName, crossElastServiceName };
    var serviceCreds = new Dictionary<string, MlServiceCredentials>();

    using (var client = new HttpClient())
    {
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", azureCredentials.Token);
        client.DefaultRequestHeaders.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));

        foreach (var wsName in serviceList)
        {
            var getWebServiceKeys =
            string.Format(
                "https://management.azure.com/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.MachineLearning/webServices/{2}/listkeys?api-version={3}",
                subscriptionId, resourceGroupName, wsName, apiVersion);

            var getWebServiceInfo =
                string.Format(
                    "https://management.azure.com/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.MachineLearning/webServices/{2}?api-version={3}",
                    subscriptionId, resourceGroupName, wsName, apiVersion);

            try
            {
                log.Info($"Getting web service information and API key for {wsName}");
                serviceCreds.Add(wsName,
                    await GetBESCredentials(client, getWebServiceInfo, getWebServiceKeys));
            }
            catch (Exception ex)
            {
                log.Info($"Error: {ex.Message}");
                throw new Exception("Getting web service info and key failed", ex);
            }
        }
    }
    
    return new
    {
        mlBuildModelEndpointUrl = serviceCreds[buildModelServiceName].EndpointUrl,
        mlBuildModelApiKey = serviceCreds[buildModelServiceName].ApiKey,
        mlFcastEndpointUrl = serviceCreds[fcastServiceName].EndpointUrl,
        mlFcastApiKey = serviceCreds[fcastServiceName].ApiKey,
        mlElastEndpointUrl = serviceCreds[elastServiceName].EndpointUrl,
        mlElastApiKey = serviceCreds[elastServiceName].ApiKey,
        mlCrossElastEndpointUrl = serviceCreds[crossElastServiceName].EndpointUrl,
        mlCrossElastApiKey = serviceCreds[crossElastServiceName].ApiKey
    };
}

private static async Task<MlServiceCredentials> GetBESCredentials(HttpClient client, string getWebServiceInfo, string getWebServiceKeys)
{
    // Get the Endpoint URL first
    string apiLocation = string.Empty;
    var response = await client.GetAsync(getWebServiceInfo);
    if (response.IsSuccessStatusCode)
    {
        string content = await response.Content.ReadAsStringAsync();
        dynamic jsonObj = JsonConvert.DeserializeObject(content);
        string swaggerLocation = (string)jsonObj.properties.swaggerLocation;
        if (!string.IsNullOrEmpty(swaggerLocation))
        {
            var prefix =
                swaggerLocation.Remove(swaggerLocation.LastIndexOf("/swagger.json",
                    StringComparison.OrdinalIgnoreCase));
            prefix = prefix.TrimEnd('/');
            apiLocation = prefix;
        }
        else
        {
            throw new ArgumentNullException(getWebServiceInfo);
        }
    }
    else
    {
        string failureCode = response.StatusCode.ToString();
        string content = await response.Content.ReadAsStringAsync();
        throw new Exception($"Get ML web service info failed with errorcode: {failureCode}, Message: {content}");
    }

    // Get the Api Key
    string primaryKey = string.Empty;
    response = await client.GetAsync(getWebServiceKeys);
    if (response.IsSuccessStatusCode)
    {
        string content = await response.Content.ReadAsStringAsync();
        dynamic jsonObj = JsonConvert.DeserializeObject(content);
        primaryKey = (string)jsonObj.primary;
        if (string.IsNullOrEmpty(primaryKey))
        {
            throw new ArgumentNullException(getWebServiceKeys);
        }
    }
    else
    {
        string failureCode = response.StatusCode.ToString();
        string content = await response.Content.ReadAsStringAsync();
        throw new Exception($"Get ML web service key failed with errorcode: {failureCode}, Message: {content}");
    }

    return new MlServiceCredentials
    {
        EndpointUrl = String.Concat(apiLocation, "/jobs?api-version=2.0"),
        ApiKey = primaryKey
    };
}


