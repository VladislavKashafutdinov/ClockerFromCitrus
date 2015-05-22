package com.vladkashaf.clocker.core.starling 
{
	import flash.display.Stage;
	import flash.display.Stage3D;
	import flash.geom.Matrix;
	import flash.geom.Rectangle;
	import starling.core.Starling;
	import starling.display.DisplayObject;
	import starling.events.Event;
	import starling.utils.RectangleUtil;
	import starling.utils.ScaleMode;
	/**
	 * ...
	 * @author Kashafuutdinov Vladislav
	 */
	public class StarlingProxy 
	{
		
		private static const RENDER_MODE:String = 'auto';
		private static const HANDLE_LOST_CONTEXT:Boolean = true;
		private static const EVENT_CONTEXT3D_CREATED:String = starling.events.Event.CONTEXT3D_CREATE;
		private static const EVENT_RESIZE:String = starling.events.Event.RESIZE;
		private static const EVENT_ROOT_CREATED:String = starling.events.Event.ROOT_CREATED;
		
		/**
		 * context3D profiles to test for in Ascending order (the more important first).
		 * reset this array to a single entry to force one specific profile. <a href="http://wiki.starling-framework.org/manual/constrained_stage3d_profile">More informations</a>.
		 */
		private var _context3DProfiles:Array = [
			"standardExtended", 
			"standard", 
			"standardConstrained", 
			"baselineExtended", 
			"baseline", 
			"baselineConstrained"
		];
		private var _starling:Starling;
		private var _rootClass:Class;
		private var _stage:Stage;
		private var _baseHeight:int = -1;
		private var _baseWidth:int = -1;
		private var _viewport:Rectangle;
		
		public function StarlingProxy(rootClass:Class, stage:Stage)
		{
			_rootClass = rootClass;
			_stage = stage;
		}
		
		public function initialize(debug:Boolean, antiAliasing:uint, stage3D:Stage3D, viewport:Rectangle, onContext3DCreated:Function, onStageResize:Function):void
		{
			_viewport = viewport ? viewport : _viewport;
			
			Starling.handleLostContext = HANDLE_LOST_CONTEXT;
				
			_starling = new Starling(_rootClass, _stage, null, stage3D, RENDER_MODE, _context3DProfiles);
			
			_starling.antiAliasing = antiAliasing;
			
			_starling.showStats = debug;
			
			var handleContext3DCreated:Function = function (e:starling.events.Event):void 
			{
				_starling.removeEventListener(EVENT_CONTEXT3D_CREATED, handleContext3DCreated);
				
				onContext3DCreated(e);
			}
			
			_starling.addEventListener(EVENT_CONTEXT3D_CREATED, handleContext3DCreated);
			
			_starling.stage.addEventListener(EVENT_RESIZE, onStageResize);
		}
		public function start(onRootCreated:Function):void
		{
			if (_starling && !_starling.isStarted) {
				
				_starling.start();
				
				var handleRootCreated:Function = function (evt:starling.events.Event):void 
				{
					_starling.removeEventListener(EVENT_ROOT_CREATED, handleRootCreated);
				
					onRootCreated(evt);
				}
				
				_starling.addEventListener(EVENT_ROOT_CREATED, handleRootCreated);
			}
		}
		public function stop():void
		{
			if (_starling)
				_starling.stop();
		}
		public function removeFromStage(child:DisplayObject, dispose:Boolean):void
		{
			if (_starling)
				_starling.stage.removeChild(child, dispose);
		}
		public function addChildAtStage(child:DisplayObject, index:int):void
		{
			_starling.stage.addChildAt(child, index);
		}
		public function showStatsAt(hAlign:String, vAlign:String, scale:Number):void
		{
			if (_starling && _starling.showStats)
				_starling.showStatsAt(hAlign, vAlign, scale / _starling.contentScaleFactor);
		}
		public function destroy():void
		{
			if (_starling) 
			{
				_starling.stage.removeEventListeners(EVENT_RESIZE);
				_starling.root.dispose();
				_starling.dispose();
			}
		}
		public function resetViewport(screenWidth:Number, screenHeight:Number, viewportMode:String):void
		{
			_baseHeight = _baseHeight < 0 ? screenHeight : _baseHeight;
			_baseWidth = _baseWidth < 0 ? screenWidth : _baseWidth;

			var baseRect:Rectangle = new Rectangle(0, 0, _baseWidth, _baseHeight);
			var screenRect:Rectangle = new Rectangle(0, 0, screenWidth, screenHeight);
			
			switch (viewportMode)
			{
				case ViewportMode.LETTERBOX:
					_viewport = RectangleUtil.fit(baseRect, screenRect, ScaleMode.SHOW_ALL);
					setViewportPosition(screenWidth * .5 - _viewport.width * .5, screenHeight * .5 - _viewport.height * .5);
					setStageSize(_baseWidth, _baseHeight);
					break;
				case ViewportMode.FULLSCREEN:
					_viewport = RectangleUtil.fit(baseRect, screenRect, ScaleMode.SHOW_ALL);
					var viewportBaseRatioWidth:Number = _viewport.width / baseRect.width;
					var viewportBaseRatioHeight:Number = _viewport.height / baseRect.height;
					_viewport.copyFrom(screenRect);
					setViewportPosition(0, 0);
					setStageSize(screenRect.width / viewportBaseRatioWidth, screenRect.height / viewportBaseRatioHeight);
					break;
				case ViewportMode.NO_SCALE:
					_viewport = baseRect;
					setViewportPosition(screenWidth * .5 - _viewport.width * .5, screenHeight * .5 - _viewport.height * .5);
					setStageSize(_baseWidth, _baseHeight);
					break;
				case ViewportMode.LEGACY:
					_viewport = screenRect;
					setStageSize(screenRect.width, screenRect.height);
				case ViewportMode.MANUAL:
					_viewport = !_viewport ? _starling.viewPort.clone() : _viewport;
					break;
			}
			
			_starling.viewPort.copyFrom(_viewport);
		}
		public function applyViewportTo(transformMatrix:Matrix):void
		{
			if (_starling)
			{
				transformMatrix.identity();
				transformMatrix.scale(_starling.contentScaleFactor, _starling.contentScaleFactor);
				transformMatrix.translate(_viewport.x, _viewport.y);
			}
		}
		
		public function get starling():Starling
		{
			return _starling;
		}
		public function get context3DProfiles():Array
		{
			return _context3DProfiles;
		}
		public function get baseHeight():Number
		{
			return _baseHeight;
		}
		public function set baseHeight(value:Number):*
		{
			return _baseHeight = value;
		}
		public function get baseWidth():Number
		{
			return _baseWidth;
		}
		public function set baseWidth(value:Number):*
		{
			return _baseWidth = value;
		}
		
		private function setViewportPosition(x:Number, y:Number):void
		{
			_viewport.x = x;
			_viewport.y = y;
		}
		private function setStageSize(width:Number, height:Number):void
		{
			if (_starling)
			{
				_starling.stage.stageWidth = width;
				_starling.stage.stageHeight = height;
			}
		}

	}

}