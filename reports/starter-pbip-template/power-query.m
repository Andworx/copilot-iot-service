let
    EnvironmentUrl = "https://YOUR_ORG_URL.crm.dynamics.com",
    Source = CommonDataService.Database(EnvironmentUrl),
    ServiceRequests = Source{[Schema="dbo",Item="your_servicerequests_table"]}[Data],
    SelectedColumns = Table.SelectColumns(
        ServiceRequests,
        {
            "createdon",
            "ticketnumber",
            "statuscode",
            "prioritycode",
            "ownerid",
            "modifiedon"
        }
    )
in
    SelectedColumns
