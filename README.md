Description
===========

A flash player based RTMP encoder featuring

- "adobe" authentication (the same performed by FMLE)
- automatic video resize
- javascript interface
- log to javascript console


The root directory is a flash builder project.
"bin-debug/" folder contains a sample app.


Javascript Interface
--------------------

Get a reference to the flash object

    var producer = document.getElementsByTagName('object')[0];

Use it like this

    producer.setCredentials("username", "password");
    producer.setUrl("rtmp://127.0.0.1:1935/live");
    producer.setStreamName("foo");
    producer.setStreamWidth(640);
    producer.setStreamHeight(480);
    producer.setStreamFPS(20);
    producer.connect();

Check javascript console.

The complete API interface also includes

- getStremaName()
- getUrl()
- getStreamWidth()
- getStreamHeight()
- getStreamFPS()
- disconnect()


TODO
----

Call javascript methods (or generate events?) to notify the webapp about
errors or state changes.




