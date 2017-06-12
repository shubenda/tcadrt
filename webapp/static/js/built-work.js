// Important note: There is a certain amount of sloppiness that is tolerated by the fact that the jQuery functions
// that handle the XML returned from AJAX strips off the language tags that the SPARQL endpoint sends in the query
// results.  This means that handling the results is easier if the language tags aren't desired (which they usually 
// arent).  However, if they were desired, they would have to be generated and attached to the literals.  Also,
// if a version of this program were created where the queries requested application/sparql-results+json instead of 
// XML one would need to pay attention to whether the results included language tags or not.  The current (2016-11) 
// Heard Library SPARQL endpoint only supports XML results, but in the future cleaner code might result if the 
// program were converted to using JSON results.

var numResultstoReturn = 50; // the max number of results to return in the SPARQL search query
var isoLanguage = 'en';
var imageHtmlBlob = '';
var done = 'no'

$(document).ready(function(){

	// Main routine: execute SPARQL query to get data about temple sites

	// creates a string that contains the query with the data passed from the query string
	// inserted into the right place.  The variable values are already enclosed in quotes as necessary.
	var query = "SELECT DISTINCT ?siteName ?building ?buildingNameEn ?buildingNameZh ?buildingNameLatn ?lat ?long  WHERE {" +
	    "VALUES ?site {<"+siteURI+">}" +
	    "?site <http://www.w3.org/2000/01/rdf-schema#label> ?siteName.FILTER (lang(?siteName)='zh-latn-pinyin')" +
	    "?building <http://schema.org/containedInPlace> ?site." +
	    "OPTIONAL{?building <http://www.w3.org/2000/01/rdf-schema#label> ?buildingNameEn.FILTER ( lang(?buildingNameEn)='en')}" +
	    "OPTIONAL{?building <http://www.w3.org/2000/01/rdf-schema#label> ?buildingNameZh.FILTER ( lang(?buildingNameZh)='zh-hans')}" +
	    "OPTIONAL{?building <http://www.w3.org/2000/01/rdf-schema#label> ?buildingNameLatn.FILTER ( lang(?buildingNameLatn)='zh-latn-pinyin')}" +
	    "OPTIONAL{?building <http://www.w3.org/2003/01/geo/wgs84_pos#lat> ?lat.}" +
	    "OPTIONAL{?building <http://www.w3.org/2003/01/geo/wgs84_pos#long> ?long.}" +
	    "}" +
	    "ORDER BY ASC(?buildingName)" +
	    "LIMIT " + numResultstoReturn;

	// URL-encodes the query so that it can be appended as a query value
	var encoded = encodeURIComponent(query)

	// does the AJAX to send the HTTP GET to the Callimachus SPARQL endpoint
	// then puts the result in the "data" variable
	$.ajax({
	    type: 'GET',
	    url: 'http://rdf.library.vanderbilt.edu/sparql?query=' + encoded,
	    headers: {
		Accept: 'application/sparql-results+xml'
	    },
	    success: parseXml
	});

});

// converts nodes of an XML object to text. See http://tech.pro/tutorial/877/xml-parsing-with-jquery
// and http://stackoverflow.com/questions/4191386/jquery-how-to-find-an-element-based-on-a-data-attribute-value
function parseXml(xml) {
 
        //step through each "result" element
        $(xml).find("result").each(function() {

            tableRow="<div>";

            // pull the "binding" element that has the name attribute of "siteName"
            $(this).find("binding[name='siteName']").each(function() {
                tableRow=tableRow+"Temple site: <strong>"+$(this).find("literal").text() + "</strong>. Building: <strong>";
            });

            // pull the "binding" element that has the name attribute of "buildingNameZh"
            $(this).find("binding[name='buildingNameZh']").each(function() {
                tableRow=tableRow+$(this).find("literal").text() + " ";
            });

            // pull the "binding" element that has the name attribute of "buildingNameLatn"
            $(this).find("binding[name='buildingNameLatn']").each(function() {
                tableRow=tableRow+$(this).find("literal").text() + " ";
            });

            // pull the "binding" element that has the name attribute of "buildingNameEn"
            $(this).find("binding[name='buildingNameEn']").each(function() {
                tableRow=tableRow+"("+$(this).find("literal").text() + ") ";
            });
            
            latitude = "";

            // pull the "binding" element that has the name attribute of "lat"
            $(this).find("binding[name='lat']").each(function() {
               latitude=$(this).find("literal").text();
            });

            // pull the "binding" element that has the name attribute of "long"
            $(this).find("binding[name='long']").each(function() {
                longitude=$(this).find("literal").text();
            });
            tableRow = tableRow + '</strong><br/>'
            if (latitude!="") {
		    tableRow = tableRow + '<a target="top" href="http://maps.google.com/maps?output=classic&amp;q=loc:'+ latitude + ',';
		    tableRow = tableRow + longitude +'&amp;t=h&amp;z=16">Open location in map application</a><br/>';
		    tableRow = tableRow + '<img src="http://maps.googleapis.com/maps/api/staticmap?center='+latitude+','+longitude+'&amp;zoom=11&amp;size=300x300&amp;markers=color:green%7C'+latitude+','+longitude+'&amp;sensor=false"/>'
		    tableRow = tableRow + '<img src="http://maps.googleapis.com/maps/api/staticmap?center='+latitude+','+longitude+'&amp;maptype=hybrid&amp;zoom=18&amp;size=300x300&amp;markers=color:green%7C'+latitude+','+longitude+'&amp;sensor=false"/><br/>'
		   
		    }

		    // pull the "binding" element that has the name attribute of "building"
            $(this).find("binding[name='building']").each(function() {
                buildingURI=$(this).find("uri").text();
            });
            
            // the getBuildings function queries the endpoint for image tnumbnails and good quality accessURIs, then inserts the blob into the div
            getImages(buildingURI,tableRow);

        });
}

function getImages(buildingURI,tableRow) {
	// create URI-encoded query string
        var string = 'PREFIX ac: <http://rs.tdwg.org/ac/terms/>'
                    +'PREFIX foaf: <http://xmlns.com/foaf/0.1/>'
                    +'SELECT DISTINCT ?thumbURL ?gqURL WHERE {'
                    +"?image foaf:depicts <"+buildingURI+">."
                    +'?image ac:hasServiceAccessPoint ?thumbSap.'
                    +'?thumbSap ac:variant ac:Thumbnail.'
                    +'?thumbSap ac:accessURI ?thumbURL.'
                    +'?image ac:hasServiceAccessPoint ?gqSap.'
                    +'?gqSap ac:variant ac:GoodQuality.'
                    +'?gqSap ac:accessURI ?gqURL.'
                    +'}';
	var encodedQuery = encodeURIComponent(string);
        // send query to endpoint
        $.ajax({
            type: 'GET',
            url: 'http://rdf.library.vanderbilt.edu/sparql?query=' + encodedQuery,
            headers: {
                Accept: 'application/sparql-results+xml'
            },
//            success: parseImageXml
        })
        .done(function(xml){
	    //step through each "result" element
	    $(xml).find("result").each(function() {
	
		// pull the "binding" element that has the name attribute of "gqURL"
		$(this).find("binding[name='gqURL']").each(function() {
		    tableRow=tableRow+"<a target='_blank' href='"+$(this).find("uri").text() + "'>";
		});
	
		// pull the "binding" element that has the name attribute of "thumbURL"
		$(this).find("binding[name='thumbURL']").each(function() {
		    tableRow=tableRow+"<img src='"+$(this).find("uri").text() + "'></a> ";
		});     
	    });
	tableRow=tableRow+"<br/><br/></div>"
	$("#div1").append(tableRow);
	});
}