package com.vladkashaf.clocker.core.starling 
{

	import com.vladkashaf.clocker.core.CitrusEngine;
	import flash.display.Stage;
	import starling.core.Starling;
	import starling.display.DisplayObject;
	import starling.events.Event;
	import starling.utils.RectangleUtil;
	import starling.utils.ScaleMode;

	import flash.display.Stage3D;
	import flash.events.Event;
	import flash.geom.Rectangle;

	/**
	 * Extends this class if you create a Starling based game. Don't forget to call <code>setUpStarling</code> function.
	 * 
	 * <p>CitrusEngine can access to the Stage3D power thanks to the <a href="http://starling-framework.org/">Starling Framework</a>.</p>
	 */
	public class StarlingCitrusEngine extends CitrusEngine 
	{
		
		private static const ASSET_SIZES:Array = [1];
		private static const VIEWPORT_MODE:String = ViewportMode.LEGACY;
		
		private var _scaleFactor:Number = 1;
		private var _juggler:CitrusStarlingJuggler;
		private var _starlingProxy:StarlingProxy;
		
		public function StarlingCitrusEngine() 
		{
			super();
			
			_starlingProxy = new StarlingProxy(RootClass, stage);
			
			_juggler = new CitrusStarlingJuggler();
		}

		public function setupStats(hAlign:String = "left", vAlign:String = "top", scale:Number = 1):void
		{
			_starlingProxy.showStatsAt(hAlign, vAlign, scale);
		}
		/**
		 * You should call this function to create your Starling view. The RootClass is internal, it is never used elsewhere. 
		 * StarlingState is added on the starling stage : <code>_starling.stage.addChildAt(_state as StarlingState, _stateDisplayIndex);</code>
		 * @param debugMode If true, display a Stats class instance.
		 * @param antiAliasing The antialiasing value allows you to set the anti-aliasing (0 - 16), generally a value of 1 is totally acceptable.
		 * @param viewPort Starling's viewport, default is (0, 0, stage.stageWidth, stage.stageHeight, change to (0, 0, stage.fullScreenWidth, stage.fullScreenHeight) for mobile.
		 * @param stage3D The reference to the Stage3D, useful for sharing a 3D context. <a href="http://wiki.starling-framework.org/tutorials/combining_starling_with_other_stage3d_frameworks">More informations</a>.
		 */
		public function setUpStarling(debug:Boolean = false, antiAliasing:uint = 1, viewPort:Rectangle = null, stage3D:Stage3D = null):void 
		{
			_starlingProxy.initialize(debug, antiAliasing, stage3D, viewPort, _context3DCreated, handleStarlingStageResize);
		}

		
		/**
		 * This function is called when context3D is ready and the starling root is created.
		 * the idea is to use this function for asset loading through the starling AssetManager and create the first state.
		 */
		protected function handleStarlingReady():void { }

		protected function handleStarlingStageResize(evt:starling.events.Event):void 
		{
			resetScreenSize();
			
			onStageResize.dispatch(_screenWidth, _screenHeight);
		}
		
		protected function resetViewport():void
		{
			_starlingProxy.resetViewport(_screenWidth, _screenHeight, VIEWPORT_MODE);
			
			_scaleFactor = findScaleFactor(ASSET_SIZES);
			
			_starlingProxy.applyViewportTo(transformMatrix);
		}
		/**
		 * returns the asset size closest to one of the available asset sizes you have (based on <code>Starling.contentScaleFactor</code>).
		 * If you design your app with a Starling's stage dimension equals to the Flash's stage dimension, you will have to overwrite 
		 * this function since the <code>Starling.contentScaleFactor</code> will be always equal to 1.
		 * @param	assetSizes Array of numbers listing all asset sizes you use
		 * @return
		 */
		protected function findScaleFactor(assetSizes:Array):Number
		{
			var scaleFactor:Number = Math.floor(starling.contentScaleFactor * 1000) / 1000;
			
			return assetSizes.length > 0 
				? assetSizes
					.map(function (s:Number, ... a):* { return { assetSize:s, sort:Math.abs(s - scaleFactor) }; } )
					.sortOn('sort')[assetSizes.length - 1].assetSize
				: undefined;
		}
		/**
		 * Be sure that starling is initialized (especially on mobile).
		 */
		protected function _context3DCreated(evt:starling.events.Event):void 
		{
			resetScreenSize();
			
			_starlingProxy.start(_starlingRootCreated);
		}
		protected function _starlingRootCreated(evt:starling.events.Event):void 
		{
			stage.removeEventListener(flash.events.Event.RESIZE, handleStageResize);
			
			handleStarlingReady();
			
			setupStats();
		}
		
		
		/**
		 * @inheritDoc
		 */
		override public function destroy():void 
		{

			super.destroy();
			
			_juggler.purge();

			if (_state) 
			{
				_starlingProxy.removeFromStage(_state as StarlingState, false);
				_starlingProxy.destroy();
			}
		}
		
		/**
		 * @inheritDoc
		 */
		override protected function handlePlayingChange(value:Boolean):void
		{
			super.handlePlayingChange(value);
			
			_juggler.paused = !value;
		}

		/**
		 * @inheritDoc
		 */
		override protected function resetScreenSize():void
		{
			super.resetScreenSize();
			
			if (_starlingProxy.starling)
			{
				resetViewport();
				
				setupStats();
			}
		}

		/**
		 * @inheritDoc
		 */
		override protected function handleEnterFrame(e:flash.events.Event):void 
		{
			if (_starlingProxy.starling && _starlingProxy.starling.isStarted && _starlingProxy.starling.context) 
			{
				if (_newState && _state && _state is StarlingState) 
				{
					_state.destroy();
					_starlingProxy.removeFromStage(_state as StarlingState, true);
				} 
				else if (_newState && _state && _newState is StarlingState) 
				{
					_state.destroy();
					removeChild(_state as State);
				}
				if (_newState && _newState is StarlingState) 
				{
					_state = _newState;
					_newState = null;

					if (_futureState)
						_futureState = null;
					else 
					{
						_starlingProxy.addChildAtStage(_state as StarlingState, _stateDisplayIndex);
						_state.initialize();
					}
				}
				if (_stateTransitionning && _stateTransitionning is StarlingState) 
				{
					_futureState = _stateTransitionning;
					_stateTransitionning = null;
					_starlingProxy.addChildAtStage(_futureState as StarlingState, _stateDisplayIndex);
					_futureState.initialize();
				}
			}

			super.handleEnterFrame(e);
			
			if(_juggler)
				_juggler.advanceTime(_timeDelta);
		}
		
		/**
		 * @inheritDoc
		 * We stop Starling. Be careful, if you use AdMob you will need to override this function and set Starling stop to <code>true</code>!
		 * If you encounter issues with AdMob, you may override <code>handleStageDeactivated</code> and <code>handleStageActivated</code> and use <code>NativeApplication.nativeApplication</code> instead.
		 */
		override protected function handleStageDeactivated(e:flash.events.Event):void 
		{
			if (_playing)
				_starlingProxy.stop();

			super.handleStageDeactivated(e);
		}
		
		/**
		 * @inheritDoc
		 * We start Starling.
		 */
		override protected function handleStageActivated(e:flash.events.Event):void 
		{
			_starlingProxy.start();
			super.handleStageActivated(e);
		}
		
		
		public function get starling():Starling 
		{
			return _starlingProxy.starling;
		}
		
		public function get scaleFactor():Number
		{
			return _scaleFactor;
		}

		public function get baseWidth():int
		{
			return _starlingProxy.baseWidth;
		}
		
		public function set baseWidth(value:int):void 
		{
			_starlingProxy.baseWidth = value;
			resetViewport();
		}
		
		public function get baseHeight():int
		{
			return _starlingProxy.baseHeight;
		}
		
		public function set baseHeight(value:int):void 
		{
			_starlingProxy.baseHeight = value;
			resetViewport();
		}
		
		public function get juggler():CitrusStarlingJuggler
		{
			return _juggler;
		}
		
		protected function get context3DProfiles():Array
		{
			return _starlingProxy.context3DProfiles;
		}
		
	}
}



import starling.display.Sprite;


/**
 * RootClass is the root of Starling, it is never destroyed and only accessed through <code>_starling.stage</code>.
 */
internal class RootClass extends Sprite {

	public function RootClass() {
	}
}
