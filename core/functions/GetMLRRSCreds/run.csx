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
using System.Linq;
using System.Globalization;
using System.Collections.Generic;
using System.IO;
using System.Threading;
using System.Net.Http;
using System.Net.Http.Headers;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using Microsoft.Azure;
// using System.Reflection;

public class MlServiceCredentials
{
    public string EndpointUrl { get; set; }

    public string ApiKey { get; set; }

    public string ToString()
    {
        return String.Format("URL: {0}\r\nAPI Key: {1}", EndpointUrl, ApiKey);
    }
}

public static async Task<object> Run(HttpRequestMessage req, TraceWriter log)
{
    var parametersReader = await CiqsInputParametersReader.FromHttpRequestMessage(req);

    string subscriptionId = parametersReader.GetParameter<string>("subscriptionId");
    string resourceGroupName = parametersReader.GetParameter<string>("resourceGroupName");
    string authorizationToken = parametersReader.GetParameter<string>("authorizationToken");
    string webServiceNames = parametersReader.GetParameter<string>("webServiceNames");
    string apiVersion = parametersReader.GetParameter<string>("mlWsApiVersion");

    var azureCredentials = new TokenCloudCredentials(subscriptionId, authorizationToken);
    var wsNameArray = webServiceNames.Split(new char[] { ';', ' ' }, StringSplitOptions.RemoveEmptyEntries).Select(s => s.Trim());
    var outputList = new List<string>();

    using (var client = new HttpClient())
    {
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", azureCredentials.Token);
        client.DefaultRequestHeaders.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));

        foreach (var wsName in wsNameArray)
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
                MlServiceCredentials wsCred = await GetRRSCredentials(client, getWebServiceInfo, getWebServiceKeys);
                outputList.Add($"{wsName}:\r\n{wsCred.ToString()}");

                /* Tried creating the result object using reflection with one field per service API, Key.
                   However, reflection does not allow adding fields to regular objects (but ExpandoObject exists)
                   Additionally, the fields need to have fixed names for CIQS anyway. 
                   So better to have a fixed list of services in the function if we wanted to map services to field names.
                   
                // set the URL portion of the result object
                PropertyInfo propUrl = obj.GetType().GetProperty($"{wsName}_URL", BindingFlags.Public | BindingFlags.Instance);
                if (null != propUrl && prop.CanWrite)
                {
                    propUrl.SetValue(result, wsCred.EndpointUrl, null);
                }

                // set the API key portion of the result object
                PropertyInfo propKey = obj.GetType().GetProperty($"{wsName}_API_Key", BindingFlags.Public | BindingFlags.Instance);
                if (null != propKey && prop.CanWrite)
                {
                    propKey.SetValue(result, wsCred.ApiKey, null);
                }
                */

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
        mlRRSCredentials = string.Join("\r\n\r\n", outputList)
    };
}

private static async Task<MlServiceCredentials> GetRRSCredentials(HttpClient client, string getWebServiceInfo, string getWebServiceKeys)
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
        EndpointUrl = String.Concat(apiLocation, "/execute?api-version=2.0&format=swagger"),
        ApiKey = primaryKey
    };
}



