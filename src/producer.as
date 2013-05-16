package
{
	
	import com.hurlant.crypto.hash.IHash;
	
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.NetStatusEvent;
	import flash.external.ExternalInterface;
	import flash.media.Camera;
	import flash.media.Microphone;
	import flash.media.Video;
	import flash.net.NetConnection;
	import flash.net.NetStream;
	import flash.net.ObjectEncoding;
	import flash.text.TextField;
	import flash.utils.ByteArray;
	import flash.utils.setTimeout;
	import flash.media.H264VideoStreamSettings;
	import flash.media.H264Level;
	import flash.media.H264Profile;
	import flash.media.SoundCodec;
	
	// how to force proper codecs
	// http://www.adobe.com/devnet/adobe-media-server/articles/encoding-live-video-h264.html
	
	// since we can't use proper audio codec but only speex and soreson we have to setup wowza like this
	// http://www.wowza.com/forums/content.php?347-How-to-convert-Flash-Player-11-output-from-H-264-Speex-audio-to-H-264-AAC-audio-using-Wowza-Transcoder-AddOn
	
	public class producer extends Sprite
	{
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
		
		public function trace(string:String):void {
			ExternalInterface.call("console.log", string);
			this.statusTxt.text = string;
		}
		
		public function producer() {
			NetConnection.prototype.onBWDone = function(oObject1:Object):void {
                trace("onBWDone: " + oObject1.toString()); // some media servers are dumb, so we need to catch a strange event..
            }
				
			trace("Producer object has been created.");
			this.statusTxt.width = 640;
			this.statusTxt.height = 480;
			addChild(this.statusTxt);
			
			this.oVideo = new Video(640, 400);
			this.addChild(this.oVideo);
			this.oConnection = new NetConnection();
			this.oConnection.addEventListener(NetStatusEvent.NET_STATUS, eNetStatus, false, 0, true);
			this.oConnection.objectEncoding = ObjectEncoding.AMF0;
			
			if (ExternalInterface.available) {
				ExternalInterface.addCallback("trace", this.trace);
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
			} else {
				trace("External interface not available)");
			}
			
			// fix flash content resizing
			import flash.display.*;
			stage.align=StageAlign.TOP_LEFT;
			stage.scaleMode=StageScaleMode.NO_SCALE;
			stage.addEventListener(Event.RESIZE, updateSize);
			stage.dispatchEvent(new Event(Event.RESIZE));
		}
		
		protected function updateSize(event:Event):void {
			this.oVideo.width = stage.stageWidth;
			this.oVideo.height = stage.stageHeight;
			this.statusTxt.width = stage.stageWidth;
			this.statusTxt.height = stage.stageHeight;
		}		
		
		// External APIs
		
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
				url += "?authmod=adobe&user=testuser"
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
				trace(response);
				
				url += "&challenge=" + this.challenge + "&response=" + response + "&opaque=" + this.opaque;
			}
			
			trace("Connecting to url: " + url);
			this.oConnection.connect(url, null, null, null, forcedVersion);
		}
		
		public function disconnect():void {
			this.oConnection.close();
		}
		
		
		protected function eMetaDataReceived(oObject:Object):void {
            trace("MetaData: " + oObject.toString()); // debug trace..
		}
		
		private function eNetStatus(oEvent1:NetStatusEvent):void {
			trace("NetStatusEvent: " + oEvent1.info.code); // debug trace..
			
			switch (oEvent1.info.code) {
				case "NetConnection.Connect.Success":
					this.oCamera = Camera.getCamera();
					this.oCamera.setMode(this.streamWidth, this.streamHeight, this.streamFPS, true);
					// example if streamQualirt = 90 it's 900Kbps
					this.oCamera.setQuality(this.streamQuality * 1000, this.streamQuality);
					this.oCamera.setKeyFrameInterval(20);
					
					var h264Settings:H264VideoStreamSettings = new H264VideoStreamSettings();
					h264Settings.setProfileLevel(H264Profile.BASELINE, H264Level.LEVEL_3_1);
					
					this.oNetStream.videoStreamSettings = h264Settings;
					
					trace("Container size " + this.width + "x" + this.height);
					trace("Video size " + this.oVideo.width + "x" + this.oVideo.height);
					trace("Camera size " + this.oCamera.width + "x" + this.oCamera.height);
					
					this.oMicrophone = Microphone.getMicrophone();
					
					this.oMicrophone.codec = SoundCodec.SPEEX;
					// attach the camera to the video..
					this.oVideo.attachCamera(this.oCamera);
					// create a stream for the connection..
					
					this.oNetStream = new NetStream(oConnection);
					// attach the camera and microphone to the stream..

					this.oNetStream.attachCamera(this.oCamera);
					this.oNetStream.attachAudio(this.oMicrophone);
					// start publishing the stream..
					this.oNetStream.addEventListener(NetStatusEvent.NET_STATUS, eNetStatus, false, 0, true);
          			this.oNetStream.publish("mp4:" + this.sStreamName + ".mp4", "live");

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
					trace("Connected to the RTMP server."); // debug trace..
					break;
				case "NetConnection.Connect.Closed":
					trace("Disconnected from the RTMP server."); // debug trace..
					break;
				case "NetConnection.Connect.Rejected":
					var desc:String = oEvent1.info.description;
					if (desc !== '') {
						trace(desc);
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
								trace("Server requested credentials, trying to reconnect in 1s");
								flash.utils.setTimeout(this.connect, 1000);
							}
							
							if (parameters["reason"] == 'authfailed') {
								// invalidate current salt and try again
								this.salt = '';
								flash.utils.setTimeout(this.connect, 1000);
							}
							
						} catch(e : Error) {
							trace("ERROR: " + e.message);
						}
					}
					break;
				case "NetConnection.Connect.Closed":
					break;
				default:
					trace(oEvent1.info.code);
					break;
			}
		}
	}
}
