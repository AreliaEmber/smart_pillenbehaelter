# smart_pillenbehaelter

The repository for our product development project in WS25/26. Please save all relevant documents here whenever you're done working on them for the day so that we have everything in one place with a solid version history and good backups.


ESP files are written in .css files

options for handling WLAN problems with the esp/app:
- we use bluetooth instead and code an app for the phone that handles displaying the information to the user
- we read up on how to connect to the esp with mobile networks while the phone is still connected to the internet (might not work, we're not sure yet)
- we host the website on a server and use bluetooth connections between the phone and the esp so that we don't have to send the entire website to the phone via the esp. Should work but would be expensive
- we try to host the esp data on a local access website with a web address and use the internet on the phone to try to connect to that address
