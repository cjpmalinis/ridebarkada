# RideBarkada Elegant Frontend

This version refreshes the visual design while keeping the current Supabase MVP workflow.

Live site:
https://cjpmalinis.github.io/ridebarkada/

Before replacing files in GitHub, make sure Supabase Authentication → URL Configuration contains:

Site URL:
https://cjpmalinis.github.io/ridebarkada/

Redirect URL:
https://cjpmalinis.github.io/ridebarkada/**

The next planned upgrade is map/GPS integration, automatic route distance, live rider location and richer booking UX.


## Map MVP
This version adds a Leaflet/OpenStreetMap map, browser geolocation, place search, route distance, estimated travel time, and automatic fare calculation. The public geocoding/routing services are suitable for prototyping; use dedicated providers and follow their usage policies for production scale.
