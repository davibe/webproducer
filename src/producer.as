package
{
	
	import com.hurlant.crypto.hash.IHash;
	
	import flash.display.LoaderInfo;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.NetStatusEvent;
	import flash.events.StatusEvent;
	import flash.external.ExternalInterface;
	import flash.media.Camera;
	import flash.media.H264Level;
	import flash.media.H264Profile;
	import flash.media.H264VideoStreamSettings;
	import flash.media.Microphone;
	import flash.media.SoundCodec;
	import flash.media.Video;
	import flash.net.NetConnection;
	import flash.net.NetStream;
	import flash.net.ObjectEncoding;
	import flash.text.TextField;
	import flash.utils.ByteArray;
	import flash.utils.setTimeout;
	
	// how to force proper codecs
	// http://www.adobe.com/devnet/adobe-media-server/articles/encoding-live-video-h264.html
	
	// since we can't use proper audio codec but only speex and soreson we have to setup wowza like this
	// http://www.wowza.com/forums/content.php?347-How-to-convert-Flash-Player-11-output-from-H-264-Speex-audio-to-H-264-AAC-audio-using-Wowza-Transcoder-AddOn
	
	// events
	// ready -> the producer is ready
	// camera-approved -> the user has approved camera acess
	// connect -> rtmp connection established, data is flowing
	// disconnect -> rtmp connction has been closed
	// error -> first argument is the tipoc, second is a human readable description
	// error "no-camera" -> Could not find an available camera
	// error "net" -> 
	public class producer extends Sprite
	{
		protected var id:String;
		protected var sMediaServerURL:String = "rtmp://127.0.0.1:1935/live";
        protected var sStreamName:String = "foo";
		protected var username:String = "testuser";
		protected var password:String = "testpass";
		protected var streamWidth:int = 640;
		protected var streamHeight:int = 480;
		protected var streamQuality:int = 90;
		protected var streamFPS:int = 20;
		
        protected var oConnection:NetConnection;
        protected var oMetaData:Object = new Object();
        protected var oNetStream:NetStream;
		
		private var oVideo:Video;
		private var oCamera:Camera;
		private var oMicrophone:Microphone;
		private var statusTxt:TextField = new TextField();
		
		private var challenge:String = '';
		private var sessionId:String = '';
		private var opaque:String = '';
		private var salt:String = '';
		
		public function log(string:String):void {
			ExternalInterface.call("WebProducer.log", this.id, string);
			this.statusTxt.text = string;
		}
		
		public function js_fire(name:String, arg1:String, arg2:String):void {
			if (!arg1) arg1 = ""; if (!arg2) arg2 = "";
			ExternalInterface.call("WebProducer.js_event", this.id, name, arg1, arg2);
		}
		
		public function reloadParams():void {
			// load parameters coming from the html page, for the moment we just read the id
			var parameters:Object = LoaderInfo(this.root.loaderInfo).parameters;
			var id = parameters["id"];
			if (!id) {
				log("ERROR: you must provide an id");
				return;
			}
			this.id = id;
		}
		
		public function producer() {
			this.id = "Unknown";
			this.reloadParams();
			
			NetConnection.prototype.onBWDone = function(oObject1:Object):void {
                log("onBWDone: " + oObject1.toString()); // some media servers are dumb, so we need to catch a strange event..
            }
				
			log("Producer object has been created.");
			
			this.statusTxt.width = 640;
			this.statusTxt.height = 480;
			addChild(this.statusTxt);
			
			this.oVideo = new Video(640, 400);
			this.addChild(this.oVideo);
			this.oConnection = new NetConnection();
			this.oConnection.addEventListener(NetStatusEvent.NET_STATUS, eNetStatus, false, 0, true);
			this.oConnection.objectEncoding = ObjectEncoding.AMF0;
			
			if (ExternalInterface.available) {
				ExternalInterface.addCallback("log", this.log);
				ExternalInterface.addCallback("setCredentials", this.setCredentials);
				ExternalInterface.addCallback("getCredentials", this.getCredentials);
				ExternalInterface.addCallback("setUrl", this.setUrl);
				ExternalInterface.addCallback("getUrl", this.getUrl);
				ExternalInterface.addCallback("setStreamName", this.setStreamName);
				ExternalInterface.addCallback("getStreamName", this.getStreamName);
				ExternalInterface.addCallback("setStreamWidth", this.setStreamWidth);
				ExternalInterface.addCallback("getStreamWidth", this.getStreamWidth);
				ExternalInterface.addCallback("setStreamHeight", this.setStreamHeight);
				ExternalInterface.addCallback("getStreamHeight", this.getStreamHeight);
				ExternalInterface.addCallback("getStreamFPS", this.getStreamFPS);
				ExternalInterface.addCallback("setStreamFPS", this.setStreamFPS);
				ExternalInterface.addCallback("connect", this.connect);
				ExternalInterface.addCallback("disconnect", this.disconnect);
				ExternalInterface.addCallback("countCameras", this.countCameras);
				ExternalInterface.addCallback("isCameraMuted", this.isCameraMuted);

			} else {
				log("External interface not available)");
			}
			
			// fix flash content resizing
			import flash.display.*;
			stage.align=StageAlign.TOP_LEFT;
			stage.scaleMode=StageScaleMode.NO_SCALE;
			stage.addEventListener(Event.RESIZE, updateSize);
			stage.dispatchEvent(new Event(Event.RESIZE));
			
			this.cameraAttach();
			this.startPreview();
			this.js_fire("ready", this.id, "");

		}
		
		protected function updateSize(event:Event):void {
			this.oVideo.width = stage.stageWidth;
			this.oVideo.height = stage.stageHeight;
			this.statusTxt.width = stage.stageWidth;
			this.statusTxt.height = stage.stageHeight;
		}
		
		protected function cameraAttach():void {
			this.oCamera = Camera.getCamera(); // get the default one for now
			if (!this.oCamera) {
				this.js_fire("error", "no-camera", "No camera available");
				return;
			}
			this.oCamera.addEventListener(StatusEvent.STATUS, cameraStatus);
		}
		
		protected function cameraStatus(event:StatusEvent):void {
			switch (event.code) 
			{ 
				case "Camera.Muted": 
					this.js_fire("camera-muted", "", "");
					break; 
				case "Camera.Unmuted": 
					this.js_fire("camera-unmuted", "", "");
					break;
			}
		}
		
		// External APIs
		
		public function isCameraMuted():Boolean {
			return this.oCamera.muted;
		}
		
		public function setCredentials(username:String, password:String):void {
			this.username = username;
			this.password = password;
		}
		
		public function getCredentials():String {
			return this.username + "/" + this.password;
		}
		
		public function setUrl(url:String):void {
			this.sMediaServerURL = url;
		}
		
		public function getUrl():String {
			return this.sMediaServerURL;
		}
		
		
		public function setStreamName(streamName:String):void {
			this.sStreamName = streamName;
		}
		
		public function getStreamName():String {
			return this.sStreamName;
		}
		
		
		public function setStreamWidth(width:int):void {
			this.streamWidth = width;
		}
		
		public function getStreamWidth():int {
			return this.streamWidth;
		}
		
		
		public function setStreamHeight(height:int):void {
			this.streamHeight = height;
		}
		
		public function getStreamHeight():int {
			return this.streamHeight;
		}
		
		
		public function setStreamQuality(quality:int):void {
			this.streamQuality = quality;
		}
		
		public function getStreamQuality():int {
			return this.streamQuality;
		}
		
		
		public function setStreamFPS(fps:int):void {
			this.streamFPS = fps;
		}
		
		public function getStreamFPS():int {
			return this.streamFPS;
		}
		
		public function connect():void {
			var url:String = this.sMediaServerURL;
			var forcedVersion:String = null;
			
			if (this.username !== '') {
				forcedVersion = "FMLE/3.0";
				// since going to authenticate the same way FMLE does but we can't override
				// flashVersion on the client we tell the server to do that for us.
				// (this require a little coding on the server to receive this parameter
				// and overwrite the client object flashversion attribute)
				url += "?authmod=adobe&user=" + this.username;
			}
			
			if (this.salt !== '') {
				import com.hurlant.crypto.Crypto;
				import com.hurlant.util.Base64;
				import com.hurlant.util.Hex;

				var md5:IHash = Crypto.getHash("md5");
				
				function md5b64enc(string:String):String {
					var data:ByteArray = Hex.toArray(Hex.fromString(string));
					data = md5.hash(data);
					return Base64.encodeByteArray(data);
				}
				
				var salted:String = md5b64enc(this.username + this.salt + this.password);
				// TODO: we should not use the same challenged the server gave us
				// but generate a new random one instead
				
				var response:String;
				response = md5b64enc(salted + this.opaque + this.challenge);
				log(response);
				
				url += "&challenge=" + this.challenge + "&response=" + response + "&opaque=" + this.opaque;
			}
			
			log("Connecting to url: " + url);
			this.oConnection.connect(url, null, null, null, forcedVersion);
		}
		
		public function disconnect():void {
			this.log("Disconnecting");
			this.oConnection.close();
		}
		
		public function countCameras():int {
			return Camera.names.length;
		}
		
		public function startPreview():void {
			if (!this.oCamera) this.cameraAttach();
			if (!this.oCamera) return;
			
			this.oCamera.setMode(this.streamWidth, this.streamHeight, this.streamFPS, true);
			// example if streamQualirt = 90 it's 900Kbps
			this.oCamera.setQuality(this.streamQuality * 1000, this.streamQuality);
			this.oCamera.setKeyFrameInterval(20);
			
			log("Container size " + this.width + "x" + this.height);
			log("Video size " + this.oVideo.width + "x" + this.oVideo.height);
			log("Camera size " + this.oCamera.width + "x" + this.oCamera.height);
			
			this.oMicrophone = Microphone.getMicrophone();
			
			this.oMicrophone.codec = SoundCodec.SPEEX;
			this.oMicrophone.rate = 44;
			this.oMicrophone.setSilenceLevel(0);
			this.oMicrophone.encodeQuality = 5;
			this.oMicrophone.framesPerPacket = 2;
			
			// attach the camera to the video..
			this.oVideo.attachCamera(this.oCamera);
		}
		
		
		protected function eMetaDataReceived(oObject:Object):void {
            log("MetaData: " + oObject.toString()); // debug log..
		}
		
		private function eNetStatus(oEvent1:NetStatusEvent):void {
			log("NetStatusEvent: " + oEvent1.info.code); // debug log..
			
			switch (oEvent1.info.code) {
				case "NetConnection.Connect.Success":
					this.startPreview();
					
					this.oNetStream = new NetStream(oConnection);
					// attach the camera and microphone to the stream..

					this.oNetStream.attachCamera(this.oCamera);
					this.oNetStream.attachAudio(this.oMicrophone);
					
					var h264Settings:H264VideoStreamSettings = new H264VideoStreamSettings();
					h264Settings.setProfileLevel(H264Profile.BASELINE, H264Level.LEVEL_3_1);
					h264Settings.keyFrameInterval = 1;
					
					this.oNetStream.videoStreamSettings = h264Settings;
					
					// start publishing the stream..
					this.oNetStream.addEventListener(NetStatusEvent.NET_STATUS, eNetStatus, false, 0, true);
          			this.oNetStream.publish(this.sStreamName + "", "live");

					// send metadata
					var metaData:Object = new Object();
					
					metaData.codec = this.oNetStream.videoStreamSettings.codec;
					metaData.profile = h264Settings.profile;
					metaData.level = h264Settings.level;
					metaData.fps = this.oCamera.fps;
					metaData.bandwith = this.oCamera.bandwidth;
					metaData.height = this.oCamera.height;
					metaData.width = this.oCamera.width;
					metaData.keyFrameInterval = this.oCamera.keyFrameInterval;
					
					this.oNetStream.send( "@setDataFrame", "onMetaData", metaData);
					
					// listen for meta data..
					this.oMetaData.onMetaData = eMetaDataReceived;
					this.oNetStream.client = this.oMetaData;
					log("Connected to the RTMP server."); // debug log..
					this.js_fire("connect", "", "");
					break;
				case "NetConnection.Connect.Closed":
					log("Disconnected from the RTMP server."); // debug log..
					this.js_fire("disconnect", "", "");
					break;
				case "NetConnection.Connect.Rejected":
					var desc:String = oEvent1.info.description;
					if (desc !== '') {
						log(desc);
						try {
							var parameters : Object = {};
							var params : Array = desc.split('?')[1].split('&');
							var length : uint = params.length;
							
							for (var i : uint = 0,index : int = -1;i < length; i++) {
								var kvPair : String = params[i];
								if ((index = kvPair.indexOf("=")) > 0) {
									var key : String = kvPair.substring(0, index);
									var value : String = kvPair.substring(index + 1);
									parameters[key] = value;
								}
							}
							
							if (parameters["reason"] == 'needauth') {
								// server requires authentication -> set session variables and try again
								challenge = parameters["challenge"] || "";
								sessionId = parameters["sessionid"] || "";
								opaque = parameters["opaque"] || "";
								salt = parameters["salt"] || "";
								log("Server requested credentials, trying to reconnect in 1s");
								flash.utils.setTimeout(this.connect, 1000);
								return
							}
							
							if (parameters["reason"] == 'authfailed') {
								// invalidate current salt and try again
								this.salt = '';
								flash.utils.setTimeout(this.connect, 1000);
							}
							
							this.js_fire("error", "NetConnection.Connect.Rejected", "");
							
						} catch(e : Error) {
							log("ERROR: " + e.message);
							this.js_fire("error", e.message);
						}
					}
					break;
				case "NetConnection.Connect.Failed":
					this.js_fire("error", "NetConnection.Connect.Failed", "Unable to establish tcp connection"); 
					break;
				case "NetConnection.Connect.Closed":
					this.js_fire("disconnect", "NetConnection.Connect.Closed", ""); 
					break;
				case "NetStream.Publish.BadName":
					this.js_fire("error", "NetStream.Publish.BadName", "Bad stream name, or already taken");
					break;
				default:
					log(oEvent1.info.code);
					this.js_fire("info", oEvent1.info.code.toString(), "");
					break;
			}
		}
	}
}
