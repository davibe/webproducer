var ou = {};
var getBaseUrl = function () {
  return $("#httpBaseUrl").val();
};
var getStreamBaseUrl = function () {
  return $("#streamBaseUrl").val();
};
var openInspector = function () {
    var gui = require('nw.gui');
    gui.Window.get().showDevTools();
};


var Form = Backbone.View.extend({
  initialize: function (options) {
    _.bindAll(this);
    Backbone.View.prototype.initialize.call(this, options);

    this.applyBtn = this.$el.find(".apply-btn");
    this.applyBtn.bind('click', this.apply);

    this.$el.bind("submit", this.die);
  },

  apply: function () {
    var data = this.$el.serializeArray();
    var toJSON = function (data) {
      data = _.groupBy(data, 'name');
      _.each(data, function (val, key, list) {
        list[key] = val[0].value;
      });
      return data;
    }
    data = toJSON(data);

    producer = $('#producer')[0];
    console.log(producer);
    producer.setCredentials(data.username, data.password);
    producer.setUrl(data.serverUrl);
    producer.setStreamName(data.streamName);
    producer.setStreamWidth(640);
    producer.setStreamHeight(480);
    producer.connect();
  },

  response: function (asd) {
    if (!asd) return;
    alert(asd);
  },

  die: function (e) {
    e.stopPropagation();
    e.preventDefault();
    return false;
  }
});

var ProducerView = Backbone.View.extend({
  initialize: function (options) {
    _.bindAll(this);
    options.el = "#" + options.id
    Backbone.View.prototype.initialize.call(this, options);
    var swfVersionStr = "11.4.0";
    // To use express install, set to playerProductInstall.swf, otherwise the empty string. 
    var xiSwfUrlStr = "playerProductInstall.swf";
    var flashvars = {};
    var params = {};
    params.quality = "high";
    params.bgcolor = "#ffffff";
    params.allowscriptaccess = "sameDomain";
    params.allowfullscreen = "true";
    var attributes = {};
    attributes.align = "left";
    swfobject.embedSWF(
        "producer.swf", options.id, 
        320*1.5, 240*1.5,
        swfVersionStr, xiSwfUrlStr, 
        flashvars, params, attributes);
    // JavaScript enabled so display the flashContent div in case it is not replaced with a swf object.
    swfobject.createCSS("#" + options.id, "display:block;text-align:left;");
  },
});

$(document).ready(function () {
  var form = new Form({
    el: "form"
  });
  var producerView = new ProducerView({
    id: "producer"
  });

  try {
    $(".open-inspector").bind("click", openInspector);
  } catch (e) {}
});

if (this.process) {
  var server = require('./server');
  server.start(function (port) {
    window.location.href = "http://127.0.0.1:" + port + "/index.html";
  });
}
