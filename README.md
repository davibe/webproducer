Description
===========

A flash based RTMP encoder featuring

- "adobe" authentication (the same performed by FMLE)
- automatic video resize
- javascript interface
- log to javascript console
- works in every browser with flash plugin installed


The root directory is a flash builder project.
"bin-debug/" folder contains a sample app.


Here is how it works
--------------------


    var producer = new WebProducer({
      id: 'producer', // the html object id
      width: 320 * 1.5, // these are sizes of the player on the page
      height: 240 * 1.5, // not related to the stream resolution
      trace: false // would enable debug logs in js console
    });
    
    producer.once('ready', function () {
      console.log('The producer is now ready');
      console.log("These are methods supported by producer flash object", producer.methods);
      
      // check there is a camera available
      var numCameras = producer.countCameras();
      console.log("We have " + numCameras + " camera(s) available");
      if (numCameras == 0) return alert('there is no camera availalbe');
      
      // checking user permissions on camera
      producer.once('camera-unmuted', function () {
        console.log("Camera is now available");
        tryToConnect();
      });
      producer.on('camera-muted', function () {
        console.log("The user has denied access to the camera");
      });
      
      var cameraMuted = producer.isCameraMuted();
      if (cameraMuted) {
        console.log("The user must approve camera access");
      } else {
        console.log("The camera is available, user already approved");
        producer.fire('camera-unmuted'); // we manually trigger the event
      }
      
      
      var tryToConnect = function () {
      
        //producer.setCredentials("username", "password"); // if you want to emulate fmle auth
        var streamName = "foo"; // stream name will reflect in the recorded filename
        
        var url = 'rtmp://' +
          window.location.hostname +
          ':1935/live'; // "live/" is the RTMP application name, always the same.
        
        producer.setUrl(url);
        producer.setStreamName(streamName);
        producer.setStreamWidth(640);
        producer.setStreamHeight(480);
        
        producer.on('connect', function () {
          console.log("We are now streaming live on our channel");
        });
        
        producer.on('disconnect', function () {
          console.log("The producer has been disconnected");
        });
        
        producer.on('error', function (reason) {
          console.log("ERROR: ", reason);
        });
        
        producer.connect();
        setTimeout(function () { producer.disconnect(); }, 10000);
      }
    });


Open bin-debug/index.html to see it in action. Remeber it has to be running
on a webserver you can't open it from file:// otherwise the NetConnection would
not work (this is due to some Flash restrictions).

