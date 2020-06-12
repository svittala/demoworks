global class queryWebTele {

    public class CBPEmployee {
        public string First {get;set;}
        public string Middle {get;set;}
        public string Last {get;set;}
        public string Email {get;set;}
        public string Phone {get;set;}
        public string Zip {get;set;}
        public string Id {get;set;}
        public string OrgCode {get;set;}
        public string Updated {get;set;}
    }

    public static void queryWebTele() {
        queryWebTele(1);
    }
    public static void queryWebTele(integer i) {
        
        string endpoint = 'https://webtele.cbp.dhs.gov/v1/webSIRS?daysSinceLastUpdate=' + string.valueof(i);
        HttpRequest feedRequest = new HttpRequest();
        feedRequest.setEndpoint(endpoint);
        feedRequest.setMethod('GET');
        feedRequest.setTimeout(120000);
        Http reqhttp = new Http();
        HTTPResponse feedResponse = reqhttp.send(feedRequest);

        if(feedResponse.getStatusCode() == 200) {
            List<Object> results = (list<Object>)JSON.deserializeUntyped(feedResponse.getBody());
            for (object o : results) {
                map<string, Object> thisone = (map<string, Object>)o;
                CBPEmployee MyEmp = new CBPEmployee();
                MyEmp.Email = (string)thisone.get('Email');
                MyEmp.First = (string)thisone.get('First');
                MyEmp.Id = (string)thisone.get('Id');
                MyEmp.Last = (string)thisone.get('Last');
                MyEmp.Middle = (string)thisone.get('Middle');
                MyEmp.OrgCode = (string)thisone.get('OrgCode');
                MyEmp.Phone = (string)thisone.get('Phone');
                MyEmp.Updated = (string)thisone.get('Updated');
                MyEmp.Zip = (string)thisone.get('Zip');
        system.debug(myemp); 
                                                                                    
            }                                                                           
                                                                            
    }
}
}