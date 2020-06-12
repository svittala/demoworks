string userquery = 'SELECT Id, IsActive FROM User LIMIT 1';
string querystring='/services/data/v45.0/query/?q='+encodingutil.urlencode(userquery, 'UTF-8');
HttpRequest getRequest = new HttpRequest();
getRequest.setEndpoint('callout:ConnectSunsky' + querystring);
getRequest.setMethod('GET');
getRequest.setTimeout(120);
Http UAhttp = new Http();
HTTPResponse userResponse = UAhttp.send(getRequest);
System.debug(userResponse.getStatusCode());
System.debug(userResponse.getStatus());
System.debug(userResponse.getBody());

//get the list of header names (keys)
string[] headerkeys = userResponse.getHeaderKeys();

//create an object to store your header key-value pair
Map<string, string> headers = new map<string, string>();

//iterate through they keys, and populate your map
for(string s : headerkeys){
   headers.put(s,userResponse.getHeader(s));
   system.debug('header: ' + s + ' value: ' + userResponse.getHeader(s));
}