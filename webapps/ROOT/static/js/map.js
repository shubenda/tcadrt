$(document).ready(function() {
	
L.tileLayer('https://api.tiles.mapbox.com/v4/{id}/{z}/{x}/{y}.png?access_token={accessToken}', {
    attribution: 'Map data &#169; <a href="http://openstreetmap.org">OpenStreetMap</a> contributors, <a href="http://creativecommons.org/licenses/by-sa/2.0/">CC-BY-SA</a>, Imagery &#169; <a href="http://mapbox.com">Mapbox</a>',
    maxZoom: 18,
    id: 'mapbox.satellite',
    accessToken: 'pk.eyJ1IjoiYmFza2F1ZnMiLCJhIjoiY2oxOTdjcjNjMDdqczJxb3ZsYjl6ODRhaSJ9.hMdUZrA0kBok1XxMO6ZazA'
}).addTo(mymap);
});