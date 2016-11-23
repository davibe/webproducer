
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
