
var WebProducer = function (options) {
  if (!options || !options.id) return alert('You must provide an id for the web producer');
  this.id = options.id;
  this.width = options.width || 320;
  this.height = options.height || 240;
  this.el = null;
  this.trace = options.trace;
  WebProducer[this.id] = this; 
  this.createElement(this.id, this.width, this.height);
  this.port = '8082';
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

  get_http_base_url: function () {
    var port = '8082';
    var host = this.getUrl().split('/')[2].split(':')[0];
    var ret = ['http://', host, ':', port, '/'].join('');
    return ret;
  },

  get_http_api_base_url: function () {
    var ret = [this.get_http_base_url(), 'api/'].join('');
    return ret;
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

    this.on('disconnect', function () { self.on_disconnect(); });
  },

  on_disconnect: function () {
    var self = this;
    var fileName = self.getStreamName() + '.mp4';
    var port = '8082';
    var host = self.getUrl().split('/')[2].split(':')[0];
    var destinationUrl = [
      self.get_http_base_url(), 'contents/', fileName
    ].join('');
    // When the server has successfully transcoded the file a sentinel
    // file will be created to signal that transcoding has been successfully
    // completed.
    self._content_ready(function () {
      self.fire('save', destinationUrl, self.getStreamName());
    });
  },

  _ensure_jQuery: function () {
    if (!window.jQuery) {
      // we use jquery for jsonp
      alert('please, include jQuery first!');
    }
  },

  _content_ready: function (cb) {
    // we poll the server to until the transcoded mp4 is ready, then cb
    this._ensure_jQuery();
    var url = [
      this.get_http_api_base_url(), 'jsonp/contents/',
      this.getStreamName(), '/ready'
    ].join('');
    
    var poll = function () {
      jQuery.ajax({
				url: url,
				dataType: 'jsonp'
      }).done(cb).fail(function () {
        setTimeout(poll, 1000);
      });
    };
    poll();
  },

  deleteContent: function (contentName, cb) {
    // TODO: /jsonp/contents/<name>/delete
    this._ensure_jQuery();
    var url = [
      this.get_http_api_base_url(), 'jsonp/contents/', contentName, '/delete'
    ].join('');
    jQuery.ajax({
      url : url, dataType: 'jsonp'
    }).then(cb);
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
