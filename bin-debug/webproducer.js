
var WebProducer = function (options) {
  if (!options || !options.id) return alert('You must provide an id for the web producer');
  this.id = options.id;
  this.width = options.width || 320;
  this.height = options.height || 240;
  this.el = null;
  this.trace = options.trace;
  WebProducer[this.id] = this; 
  this.createElement(this.id, this.width, this.height);
  this.methods = [
      'setCredentials', 'getCredentials',
      'setUrl', 'getUrl',
      'setStreamName', 'getStreamName',
      'setStreamWidth', 'getStreamWidth',
      'setStreamHeight', 'getStreamHeight',
      'setStreamFPS', 'getStreamFPS',
      'connect', 'disconnect',
      'countCameras', 'isCameraMuted'];
};

WebProducer.log = function (id) {
  if (console && console.log) {
    var producer = WebProducer[id];
    if (producer.trace) {
      console.log.apply(console, arguments);
    }
  }
};

WebProducer.js_event = function (producerId, eventName, arg1, arg2) {
  var producer = WebProducer[producerId];
  if (producer.trace)
    WebProducer.log(producerId, eventName, arg1, arg2);
  WebProducer[producerId].fire(eventName, arg1, arg2);
};

WebProducer.prototype = {
  createElement: function (id, width, height) {
    var swfVersionStr = "11.4.0";
    var xiSwfUrlStr = "playerProductInstall.swf";
    var flashvars = { id: id };
    var params = {};
    params.quality = "high";
    params.bgcolor = "#ffffff";
    params.allowscriptaccess = "sameDomain";
    params.allowfullscreen = "true";
    var attributes = {};
    attributes.align = "left";
    swfobject.embedSWF(
        "producer.swf", "producer", 
        width, height,
        swfVersionStr, xiSwfUrlStr, 
        flashvars, params, attributes);
    // JavaScript enabled so display the flashContent div in case it is not replaced with a swf object.
    swfobject.createCSS("#producer", "display:block;text-align:left;");
    
    var self = this;
    this.on('ready', function () {
      self.on_ready.apply(self, arguments);
    });
  },
  
  on_ready: function () {
    this.el = document.getElementById(this.id);
    this.flash = this.el;
    var methods = this.methods;
    var self = this;
    methods.forEach(function (method) {        
      self[method] = function () {
        return self.el[method].apply(self.el, arguments);
      };
    });

    this.on('disconnect', function () {
      // since the server is currently set to stream-record the file to disk
      // and close it as soon as the producer disconnect the file is actually
      // ready right away.
      var self = this;
      var fileName = this.getStreamName() + '.mp4';
      var port = '8082';
      var host = this.getUrl().split('/')[2].split(':')[0];
      var destinationUrl = [
        'http://', host, ':', port, '/contents/', fileName
      ].join('');
      // When the server has successfully transcoded the file a sentinel
      // file will be created to signal that transcoding has been successfully
      // completed.
      var sentinelUrl = [
        'http://', host, ':', port, '/contents/', fileName, '.done'
      ].join('');
      self.checkFileReady(sentinelUrl, function () {
        console.log("Sentinel ready" , sentinelUrl);
        self.fire('save', destinationUrl);
      });
      /*
      setTimeout(function () {
        self.fire('save', destinationUrl);
      }, 1000);
      */
    });
  },

  checkFileReady: function (url, cb) {
    // we poll the server to until the transcoded mp4 is ready, then cb
    if (!window.jQuery) {
      alert('please, include jQuery!');
      setTimeout(cb, 1000);
    }
    var poll = function () {
      jQuery.ajaxSetup({
        crossDomain: true
      });
      if (window.XDomainRequest) {
        // I am so sorry i'm doing this..
        var xdr = new window.XDomainRequest();
        xdr.open('get', url);
        xdr.onload = function () { cb(); };
        xdr.onerror = function () { setTimeout(poll, 1000); };
        xdr.send();
        return;
      }
      jQuery.get(url).done(cb).fail(function () {
        console.log("Sentinel not found, try again", url);
        setTimeout(poll, 1000);
      });
    };
    poll();
  },
  
  // Minimal event emitter prototype
  on: function(event, fct){
    this._events = this._events || {};
    this._events[event] = this._events[event] || [];
    this._events[event].push(fct);
  },
  off: function(event, fct){
    this._events = this._events || {};
    if( event in this._events === false  )  return;
    this._events[event].splice(this._events[event].indexOf(fct), 1);
  },
  fire: function(event /* , args... */){
    this._events = this._events || {};
    if( event in this._events === false  )  return;
    for(var i = 0; i < this._events[event].length; i++){
      this._events[event][i].apply(this, Array.prototype.slice.call(arguments, 1));
    }
  },
  once: function (event, fct) {
    var self = this;
    var wrapper = function () {
      self.off(event, wrapper);
      fct.apply(this, arguments); 
    };
    this.on(event, wrapper);
  }
};
