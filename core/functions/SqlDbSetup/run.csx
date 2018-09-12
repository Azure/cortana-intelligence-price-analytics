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

#r "System.Data"
#r "Microsoft.SqlServer.Smo"
#r "Microsoft.SqlServer.ConnectionInfo"
#load "..\CiqsHelpers\All.csx"

using System;
using System.Collections.Generic;
using System.IO;
using System.Globalization;
using System.Threading;
using System.Net;
using System.Data;
using System.Data.SqlClient;
using Microsoft.SqlServer.Management.Smo;
using Microsoft.SqlServer.Management.Common;

public static async Task<object> Run(HttpRequestMessage req, TraceWriter log)
{
    var parametersReader = await CiqsInputParametersReader.FromHttpRequestMessage(req);
    string sqlServerName = parametersReader.GetParameter<string>("sqlServerName");
    string sqlServerUser = parametersReader.GetParameter<string>("sqlServerUser");
    string sqlServerPasswd = parametersReader.GetParameter<string>("sqlServerPasswd");
    string sqlDbName = parametersReader.GetParameter<string>("sqlDbName");
    string createObjectsScriptPath = parametersReader.GetParameter<string>("createObjectsScriptPath");
    string OJDataPath = parametersReader.GetParameter<string>("OJDataPath");
    string fcastDataPath = parametersReader.GetParameter<string>("fcastDataPath");
    string elastDataPath = parametersReader.GetParameter<string>("elastDataPath");
    string crossElastDataPath = parametersReader.GetParameter<string>("crossElastDataPath");
    string underOverDataPath = parametersReader.GetParameter<string>("underOverDataPath");
    string suggestionRunsDataPath = parametersReader.GetParameter<string>("suggestionRunsDataPath");
    string postBcpScriptPath = parametersReader.GetParameter<string>("postBcpScriptPath");
    
    const string OJRawTableName = "etl.oj_data_raw";
    const string elastTableName = "dbo.Elasticities";
    const string crossElastTableName = "dbo.CrossElasticities";
    const string fcastTableName = "dbo.Forecasts";
    const string underOverTableName = "dbo.UnderOver";
    const string suggestionRunsTableName = "dbo.SuggestionRuns";

    string sqlConnectionString = String.Format(
               "Data Source={0}.database.windows.net;Initial Catalog={1};Persist Security Info=False;User ID={2};Password={3};Connect Timeout=60;Encrypt=True;TrustServerCertificate=False",
               sqlServerName,
               sqlDbName,
               sqlServerUser,
               sqlServerPasswd);

    //log.Info($"SQL Connection String: {sqlConnectionString}");
    
    // Create database objects
    log.Info("Creating database objects...");
    await executeSqlScript(sqlConnectionString, createObjectsScriptPath, log);

    // Load data to SQL tables
    log.Info("Loading raw OJ data into SQL table...");
    int numRows = await loadDataToTable(sqlConnectionString, OJDataPath, OJRawTableName, log);
    log.Info($"Loaded {numRows} rows");
    
    log.Info("Loading forecast data into SQL table...");
    numRows = await loadDataToTable(sqlConnectionString, fcastDataPath, fcastTableName, log);
    log.Info($"Loaded {numRows} rows");
    
    log.Info("Loading elasticity data into SQL table...");
    numRows = await loadDataToTable(sqlConnectionString, elastDataPath, elastTableName, log);
    log.Info($"Loaded {numRows} rows");

    log.Info("Loading cross-elasticity data into SQL table...");
    numRows = await loadDataToTable(sqlConnectionString, crossElastDataPath, crossElastTableName, log);
    log.Info($"Loaded {numRows} rows");

    log.Info("Loading under/over data into SQL table...");
    numRows = await loadDataToTable(sqlConnectionString, underOverDataPath, underOverTableName, log);
    log.Info($"Loaded {numRows} rows");

    log.Info("Loading suggestion runs data into SQL table...");
    numRows = await loadDataToTable(sqlConnectionString, suggestionRunsDataPath, suggestionRunsTableName, log);
    log.Info($"Loaded {numRows} rows");

    // Post load actions
    log.Info("Executing post BCP actions...");
    await executeSqlScript(sqlConnectionString, postBcpScriptPath, log);
    
    return new
    {
        finished = true
    };
}

private static async Task<int> executeSqlScript(string sqlConnectionString, string sqlScriptPath, TraceWriter log)
{
    Uri sqlScriptUri = new Uri(sqlScriptPath);
    int rowCount = 0;
    using (WebClient client = new WebClient())
    {
        string sqlScriptContent = client.DownloadString(sqlScriptUri);
        using (SqlConnection connection = new SqlConnection(sqlConnectionString))
        {
            var server = new Server(new ServerConnection(connection));
            rowCount = server.ConnectionContext.ExecuteNonQuery(sqlScriptContent);
        }
    }

    return (rowCount);
}  

private static async Task<int> loadDataToTable(string sqlConnectionString, string dataPath, string tableName, TraceWriter log)
{
    DataTable srcData = new DataTable();

    // Read BLOB content and load into the DataTable object
    using (WebClient client = new WebClient())
    {
        using (StreamReader sr = new StreamReader(client.OpenRead(dataPath)))
        {
            string[] columns = new string[0];
            string line = sr.ReadLine();
            if (string.IsNullOrWhiteSpace(line)) {
                log.Error($"File {dataPath} appears empty or starts with a blank line. End of stream = {sr.EndOfStream}");
                // pass - there are no columns
            } else {
                columns = line.Split(',');
            }

            foreach (var col in columns)
            {
                srcData.Columns.Add(col);
            }

            while (!sr.EndOfStream)
            {
                DataRow newRow = srcData.NewRow();
                var stringItemsInput = sr.ReadLine().Split(',');
                
                for(int i=0; i<stringItemsInput.Length; i++) {
                    if(String.IsNullOrEmpty(stringItemsInput[i])) {
                        newRow[i] = DBNull.Value;
                    } else {
                        newRow[i] = stringItemsInput[i];
                    }
                }
                //newRow.ItemArray = sr.ReadLine().Split(',');
                srcData.Rows.Add(newRow);
            }
        }
    }

    using (SqlConnection sqlConnection = new SqlConnection(sqlConnectionString))
    {
        sqlConnection.Open();
        using (SqlBulkCopy bcp = new SqlBulkCopy(sqlConnection))
        {
            bcp.DestinationTableName = tableName;
            bcp.BulkCopyTimeout = 180;
            bcp.WriteToServer(srcData); 
        }
    }

    return (srcData.Rows.Count);
}
