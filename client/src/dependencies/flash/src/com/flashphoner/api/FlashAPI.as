/*
Copyright (c) 2011 Flashphoner
All rights reserved. This Code and the accompanying materials
are made available under the terms of the GNU Public License v2.0
which accompanies this distribution, and is available at
http://www.gnu.org/licenses/old-licenses/gpl-2.0.html

Contributors:
    Flashphoner - initial API and implementation

This code and accompanying materials also available under LGPL and MPL license for Flashphoner buyers. Other license versions by negatiation. Write us support@flashphoner.com with any questions.
*/

package com.flashphoner.api
{
	import com.flashphoner.Logger;
	
	import flash.events.TimerEvent;
	import flash.external.ExternalInterface;
	import flash.media.Camera;
	import flash.media.Microphone;
	import flash.media.SoundCodec;
	import flash.media.SoundTransform;
	import flash.net.Responder;
	import flash.net.SharedObject;
	import flash.system.Capabilities;
	import flash.system.Security;
	import flash.utils.Timer;
	
	import mx.collections.ArrayCollection;

	[Bindable]
	public class FlashAPI
	{
		/**
		 * @private
		 **/
		internal var phoneServerProxy:PhoneServerProxy;

		/**
		 * @private
		 * Notifier added by addNotify()
		 **/ 
		public static var apiNotifys:ArrayCollection;		
		
		/**
		 * Control of video
		 **/
		public var videoControl:VideoControl;
		
		private var mic:Microphone;

		private var micIndex:int = -1;
		
		private var userData:Object;
		
		private var currentGain:int = -1;
		
		public var configuration:Object;
		
		/**
		 * Default contructor.
		 * Initialize calls,modelLocato and initialize library
		 */		
		public function FlashAPI(apiNotify:APINotify){
			Security.allowDomain("*");
			Logger.init();
			this.mic = defineMicrophone(true);
			initMic(this.mic);
			apiNotifys = new ArrayCollection();
			addAPINotify(apiNotify);
			ExternalInterface.addCallback("connect", connect);
			ExternalInterface.addCallback("talk", talk);
			ExternalInterface.addCallback("hold", hold);
			ExternalInterface.addCallback("getStatistics", getStatistics);
			ExternalInterface.addCallback("changeVideoState",changeVideoState);
			ExternalInterface.addCallback("setAudioCodec", setAudioCodec);
			ExternalInterface.addCallback("close", close);
			ExternalInterface.addCallback("publishStream", publishStream);
			ExternalInterface.addCallback("unPublishStream", unPublishStream);
			ExternalInterface.addCallback("playStream", playStream);
			ExternalInterface.addCallback("stopStream", stopStream);
			ExternalInterface.addCallback("hasAccessToAudio",hasAccessToAudio);
			ExternalInterface.addCallback("disconnect",disconnect);
			ExternalInterface.addCallback("getMicrophoneGain",getMicVolume);
			ExternalInterface.addCallback("setMicrophoneGain",setMicVolume);
			ExternalInterface.addCallback("muteVideo",muteVideo);
			ExternalInterface.addCallback("unmuteVideo",unmuteVideo);
			ExternalInterface.addCallback("isVideoMuted",isVideoMuted);
			ExternalInterface.addCallback("mute",mute);
			ExternalInterface.addCallback("unmute",unmute);
			ExternalInterface.addCallback("getVolume",getVolume);
			ExternalInterface.addCallback("setVolume",setVolume);
			ExternalInterface.addCallback("getMicropones",getMicropones);
			ExternalInterface.addCallback("setMicrophone",setMicrophone);
			ExternalInterface.addCallback("getCameras",getCameras);
			ExternalInterface.addCallback("setCamera",setCamera);

			videoControl = new VideoControl();
			
			phoneServerProxy = new PhoneServerProxy(this);
		}
		
		public  function connect(urlFlashServer:String, userData:Object, configuration:Object):void{
			this.userData = userData;
			this.configuration = configuration;
			var connectObj:Object = new Object();
			connectObj.token = userData.authToken;
			videoControl.init(configuration);
			phoneServerProxy.connect(urlFlashServer, connectObj);
		}
		
		public function changeVideoState(callId:String, hasVideo:Boolean):void{
			if (hasVideo){
				phoneServerProxy.enableVideo(getPublishStreamName(userData.sipLogin, callId));
			} else {
				phoneServerProxy.disableVideo(getPublishStreamName(userData.sipLogin, callId));
			}
		}
		
		public  function talk(callId:String, hasVideo:Boolean):void{
			phoneServerProxy.phoneSpeaker.play(getPlayStreamName(userData.sipLogin, callId), false);
			phoneServerProxy.publish(getPublishStreamName(userData.sipLogin, callId), true, hasVideo);
		}
		
		public  function hold(callId:String):void{
			phoneServerProxy.hold(getPublishStreamName(userData.sipLogin, callId));
		}
		
		public  function getStatistics(callId:String):Object{
			var statistics:Object = new Object();
			statistics.outgoingStreams = phoneServerProxy.getStatistics(getPublishStreamName(userData.sipLogin, callId));
			statistics.incomingStreams = phoneServerProxy.phoneSpeaker.getStatistics(getPlayStreamName(userData.sipLogin, callId));
			return statistics;
		}
		
		public  function setAudioCodec(id:String, codecObj:Object):void{
			changeAudioCodec(codecObj);
		}		
		
		public function close(callId:String):void{
			phoneServerProxy.phoneSpeaker.stop(getPlayStreamName(userData.sipLogin, callId));
			phoneServerProxy.unpublish(getPublishStreamName(userData.sipLogin, callId));
		}
		
		public  function publishStream(mediaSessionId:String, hasAudio:Boolean, hasVideo:Boolean, bitrate:int, quality:int):void{
			videoControl.setCamParams(bitrate, quality);
			phoneServerProxy.publish(getPublishStreamName(null, mediaSessionId), hasAudio, hasVideo);
		}
		
		public  function unPublishStream(mediaSessionId:String):void{
			phoneServerProxy.unpublish(getPublishStreamName(null, mediaSessionId));
		}
		
		public  function playStream(mediaSessionId:String):void{
			this.phoneServerProxy.phoneSpeaker.play(getPlayStreamName(null, mediaSessionId), true);			
		}
		
		public  function stopStream(mediaSessionId:String):void{
			this.phoneServerProxy.phoneSpeaker.stop(getPlayStreamName(null, mediaSessionId));			
		}
		
		public  function disconnect():void{
			phoneServerProxy.disconnect();
		}
		
		
		/**
		 * Get controller of speaker
		 **/		
		public function getPhoneSpeaker():PhoneSpeaker{
			return this.phoneServerProxy.phoneSpeaker;
		}

		/**
		 * Add notifier to api
		 * @param apiNotify Object will be implemented APINotify
		 **/
		public function addAPINotify(apiNotify:APINotify):void{
			FlashAPI.apiNotifys.addItem(apiNotify);
		}

		/**
		 * Get volume of current microphone
		 * @return volume interval 1-100
		 **/
		public function getMicVolume():int{
			if (mic == null){
				return 0;
			}else{
				return mic.gain;	
			}
			
		}
		
		/**
		 * Set volume for current microphone
		 * @param volume interval 1-100
		 **/
		public function setMicVolume(volume:int):void{
			if (mic != null){
				mic.gain = volume;
			}
		}
		
		public function muteVideo():void{
			phoneServerProxy.muteVideo();
		}
		
		public function unmuteVideo():void{
			phoneServerProxy.unmuteVideo();
		}
		
		public function isVideoMuted():Boolean{
			return phoneServerProxy.isVideoMuted();
		}		
		
		
		
		public function mute():void{
			if (mic != null){
				if (mic.gain != 0) {
					currentGain = mic.gain;
					mic.gain = 0;
					Logger.info("Mute stream");
				} else {
					Logger.info("Stream already muted");
				}
			}
		}
		
		public function unmute():void{
			if (mic != null && currentGain != -1){
				mic.gain = currentGain;
				Logger.info("Unmute stream");
				currentGain = -1;
			}
		}		
		
		/**
		 * Get volume of speakers
		 * @return volume interval 1-100
		 **/
		public function getVolume(callId:String):int{
			return phoneServerProxy.phoneSpeaker.getVolume();
		}
		
		/**
		 * Set volume for speakers
		 * @param volume interval 1-100
		 **/
		public function setVolume(callId:String, volume:int):void{
			phoneServerProxy.phoneSpeaker.setVolume(volume);
		}
		
		/**
		 * Get list of microphones
		 **/
		public function getMicropones():Array{
			return Microphone.names;
		}
		
		public function getMicrophone():Microphone{
			return mic;
		}

		public function getMicIndex():int{
			return micIndex;
		}

		/**
		 * Set current microphone
		 * @param name name of microphone
		 **/
		public function setMicrophone(name:String):void{
			var i:int = 0;
			for each (var nameMic:String in Microphone.names){
				if (nameMic == name){
					var microphone:Microphone = defineMicrophone(false, i);
					if (microphone != null){
						this.mic = microphone;
						if (this.mic != null){	
							initMic(mic,-1,false);
						}
					}					
					return;						
				}
				i++;				
			}
		}
		
		/**
		 * Check access to the devices (mic,camera)
		 **/
		public function hasAccessToAudio():Boolean{
			var m:Microphone = getMicrophone();
			if (m == null){
				return false;
			}else{
				if (m.muted){
					return false;
				}else{
					return true;
				}
				
			}
		}
		
		/**
		 * Get list of cameras
		 **/
		public function getCameras():Array{
			return Camera.names;
		}
		
		/**
		 * Set current camera
		 * @param name name of camera
		 **/		
		public function setCamera(name:String):void{
			videoControl.changeCamera(Camera.getCamera(name));
		}
		
		private function  defineMicrophone(useEnhanced:Boolean, index:int=-1):Microphone {
			Logger.info("getMicrophone "+index);
			if (useEnhanced){				
				if (getFlashPlayerMajorVersion() >= 11 || Capabilities.language.indexOf("en") >= 0){
					this.micIndex = index;
					return Microphone.getEnhancedMicrophone(index);				
				}else{					
					for each (var apiNotify:APINotify in FlashAPI.apiNotifys){
						apiNotify.addLogMessage("WARNING!!! Echo cancellation is turned off on your side (because your OS has no-english localization). Please use a headset to avoid echo for your interlocutor.");
					}
					this.micIndex = index;
					return Microphone.getMicrophone(index);
				}
			}else{
				this.micIndex = index;
				return Microphone.getMicrophone(index);
			}
		}	
		
		public function getFlashPlayerMajorVersion():int {
			var flashPlayerVersion:String = Capabilities.version;			
			var osArray:Array = flashPlayerVersion.split(' ');
			var osType:String = osArray[0];
			var versionArray:Array = osArray[1].split(',');
			return parseInt(versionArray[0]);
		}		
		
		private function initMic(mic:Microphone, gain:int=50, loopback:Boolean=false):void{
			if (mic != null){
				changeCodec("pcma");
				
				if (gain != -1){
					mic.gain = gain;
				}
			
				mic.soundTransform = new SoundTransform(1,0);			
				mic.setLoopBack(loopback);			
				mic.setSilenceLevel(0,3600000);
				mic.setUseEchoSuppression(true);
			}
		}
		
		public function changeAudioCodec(codec:Object):void{			
			var codecName:String = codec.name;
			Logger.info("changeAudioCodec: "+codecName);
			changeCodec(codecName);
		}
		
		private function changeCodec(name:String):void{
			Logger.info("changeCodec: "+name);
			if (name=="speex"){
				mic.codec = SoundCodec.SPEEX;
				mic.framesPerPacket = 1;
				mic.rate = 16;
				mic.encodeQuality = 6;
			}else if (name=="ulaw" || name=="pcmu" ){
				mic.codec = SoundCodec.PCMU;
				mic.framesPerPacket = 2;
				mic.rate = 8;
			}else if (name=="alaw" || name=="pcma" ){
				mic.codec = SoundCodec.PCMA;
				mic.framesPerPacket = 2;
				mic.rate = 8;
			}
		}
		
		public function pong():void {
			phoneServerProxy.pong();
		}		
		
		private function getPublishStreamName(login:String, sessionId:String):String {
			if (login){
				return "OUT_" + login+ "_" + sessionId;
			} else {
				return "OUT_" + sessionId;
			}
		}
		
		private function getPlayStreamName(login:String, sessionId:String):String {
			if (login){
				return "IN_" + login + "_" + sessionId;
			} else {
				return "IN_" + sessionId;
			}
			
			
		}
		
		
	}
}
