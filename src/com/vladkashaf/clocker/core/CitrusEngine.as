package com.vladkashaf.clocker.core {

	import com.vladkashaf.clocker.input.Input;
	import com.vladkashaf.clocker.sounds.SoundManager;
	import com.vladkashaf.clocker.utils.AGameData;
	import com.vladkashaf.clocker.utils.LevelManager;
	import org.osflash.signals.Signal;

	import flash.display.MovieClip;
	import flash.display.StageAlign;
	import flash.display.StageDisplayState;
	import flash.display.StageScaleMode;
	import flash.events.Event;
	import flash.events.FullScreenEvent;
	import flash.geom.Matrix;
	import flash.media.SoundMixer;
	
	/**
	 * CitrusEngine is the top-most class in the library. When you start your project, you should make your
	 * document class extend this class unless you use Starling. In this case extends StarlingCitrusEngine.
	 * 
	 * <p>CitrusEngine is a singleton so that you can grab a reference to it anywhere, anytime. Don't abuse this power,
	 * but use it wisely. With it, you can quickly grab a reference to the manager classes such as current State, Input and SoundManager.</p>
	 */	
	public class CitrusEngine extends MovieClip
	{
		public static const VERSION:String = "3.1.10";
		/**
		 * the matrix that describes the transformation required to go from state container space to flash stage space.
		 * note : this does not include the camera's transformation.
		 * the transformation required to go from flash stage to in state space when a camera is active would be obtained with
		 * var m:Matrix = camera.transformMatrix.clone();
		 * m.concat(_ce.transformMatrix);
		 * 
		 * using flash only, the state container is aligned and of the same scale as the flash stage, so this is not required.
		 */
		public const transformMatrix:Matrix = new Matrix();

		private static var _instance:CitrusEngine;
		private var _timeDeltaInner:Number;
		private var _stateTransitionningInner:IState;
		private var _stateInner:IState;
		private var _screenWidthInner:int = 0;
		private var _screenHeightInner:int = 0;
		private var _newStateInner:IState;
		private var _inputInner:Input;
		private var _playingInner:Boolean = true;
		private var _futureStateInner:IState;
		private var _stateDisplayIndexInner:uint = 0;
		private var _startTime:Number;
		// what is it??
		private var _gameTime:Number;
		private var _nowTime:Number;
		private var _sound:SoundManager;
		private var _console:Console;
		private var _debug:Boolean = false;
		private var _gameData:AGameData;
		private var _levelManager:LevelManager;
		private var _onPlayingChange:Signal;
		private var _onStageResize:Signal;
		private var _fullScreenInner:Boolean = false;
		
		public function get fullScreen():Boolean
		{
			return _fullScreen;
		}
		public function set fullScreen(value:Boolean):void
		{
			if (value == _fullScreen)
				return;
				
			if(value)
				stage.displayState = StageDisplayState.FULL_SCREEN_INTERACTIVE;
			else
				stage.displayState = StageDisplayState.NORMAL;
			
			resetScreenSize();
		}
		public function get screenWidth():int
		{
			return _screenWidth;
		}
		public function get screenHeight():int
		{
			return _screenHeight;
		}
		/**
		 * DEBUG is not used by CitrusEngine, it is there for your own convenience
		 * so you can access it wherever the _ce 'shortcut' is. defaults to false.
		 */
		public function get DEBUG():Boolean
		{
			return _debug;
		}
		public function set DEBUG(value:Boolean):*
		{
			return _debug = value;
		}
		/**
		 * Used to pause animations in SpriteArt and StarlingArt.
		 */
		public function get onPlayingChange():Signal
		{
			return _onPlayingChange;
		}
		public function set onPlayingChange(value:Signal):*
		{
			return _onPlayingChange = value;
		}
		/**
		 * called after a stage resize event
		 * signal passes the new screenWidth and screenHeight as arguments.
		 */
		public function get onStageResize():Signal
		{
			return _onStageResize;
		}
		public function set onStageResize(value:Signal):*
		{
			return _onStageResize = value;
		}
		/**
		 * You may use a class to store your game's data, this is already an abstract class made for that. 
		 * It's also a dynamic class, so you won't have problem to access information in its extended class.
		 */
		public function get gameData():AGameData
		{
			return _gameData;
		}
		public function set gameData(value:AGameData):*
		{
			return _gameData = value;
		}
		/**
		 * You may use the Citrus Engine's level manager if you have several levels to handle. Take a look on its class for more information.
		 */
		public function get levelManager():LevelManager
		{
			return _levelManager;
		}
		public function set levelManager(value:LevelManager):*
		{
			return _levelManager = value;
		}
		/**
		 * A reference to the active game state. Actually, that's not entirely true. If you've recently changed states and a tick
		 * hasn't occurred yet, then this will reference your new state; this is because actual state-changes only happen pre-tick.
		 * That way you don't end up changing states in the middle of a state's tick, effectively fucking stuff up.
		 * 
		 * If you had set up a futureState, accessing the state it wil return you the futureState to enable some objects instantiation 
		 * (physics, views, etc).
		 */		
		public function get state():IState
		{
			if (_futureState)
				return _futureState;
						
			else if (_newState)
				return _newState;
						
			else 
				return _state;
		}
		/**
		 * We only ACTUALLY change states on enter frame so that we don't risk changing states in the middle of a state update.
		 * However, if you use the state getter, it will grab the new one for you, so everything should work out just fine.
		 */		
		public function set state(value:IState):void
		{
			_newState = value;
		}
		/**
		 * Get a direct access to the futureState. Note that the futureState is really set up after an update so it isn't 
		 * available via state getter before a state update.
		 */
		public function get futureState():IState {
			return _futureState ? _futureState : _stateTransitionning;
		}
		/**
		 * The futureState variable is useful if you want to have two states running at the same time for making a transition. 
		 * Note that the futureState is added with the same index than the state, so it will be behind unless the state runs 
		 * on Starling and the futureState on the display list (which is absolutely doable).
		 */
		public function set futureState(value:IState):void {
			_stateTransitionning = value;
		}
		/**
		 * @return true if the Citrus Engine is playing
		 */		
		public function get playing():Boolean
		{
			return _playing;
		}
		/**
		 * Runs and pauses the game loop. Assign this to false to pause the game and stop the
		 * <code>update()</code> methods from being called.
		 * Dispatch the Signal onPlayingChange with the value.
		 * CitrusEngine calls its own handlePlayingChange listener to
		 * 1.reset all input actions when "playing" changes
		 * 2.pause or resume all sounds.
		 * override handlePlayingChange to override all or any of these behaviors.
		 */
		public function set playing(value:Boolean):void
		{
			if (value == _playing)
				return;
				
			_playing = value;
			if (_playing)
				_gameTime = new Date().time;
			onPlayingChange.dispatch(_playing);
		}
		/**
		 * You can get access to the Input manager object from this reference so that you can see which keys are pressed and stuff. 
		 */		
		public function get input():Input
		{
			return _input;
		}
		/**
		 * A reference to the SoundManager instance. Use it if you want.
		 */		
		public function get sound():SoundManager
		{
			return _sound;
		}
		/**
		 * A reference to the console, so that you can add your own console commands. See the class documentation for more info.
		 * The console can be opened by pressing the tab key.
		 * There is one console command built-in by default, but you can add more by using the addCommand() method.
		 * 
		 * <p>To try it out, try using the "set" command to change a property on a CitrusObject. You can toggle Box2D's
		 * debug draw visibility like this "set Box2D visible false". If your Box2D CitrusObject instance is not named
		 * "Box2D", use the name you gave it instead.</p>
		 */		
		public function get console():Console
		{
			return _console;
		}
		
		protected function get _state():IState
		{
			return _stateInner;
		}
		protected function set _state(value:IState):*
		{
			return _stateInner = value;
		}
		protected function get _newState():IState
		{
			return _newStateInner;
		}
		protected function set _newState(value:IState):*
		{
			return _newStateInner = value;
		}
		// transitioning of state? what? why IState?
		protected function get _stateTransitionning():IState
		{
			return _stateTransitionningInner;
		}
		protected function set _stateTransitionning(value:IState):*
		{
			return _stateTransitionningInner = value;
		}
		// what is difference with _newState?
		protected function get _futureState():IState
		{
			return _futureStateInner;
		}
		protected function set _futureState(value:IState):*
		{
			return _futureStateInner = value;
		}
		protected function get _stateDisplayIndex():uint
		{
			return _stateDisplayIndexInner;
		}
		protected function set _stateDisplayIndex(value:uint):*
		{
			return _stateDisplayIndexInner = value;
		}
		protected function get _playing():Boolean
		{
			return _playingInner;
		}
		protected function set _playing(value:Boolean):*
		{
			return _playingInner = value;
		}
		protected function get _input():Input
		{
			return _inputInner;
		}
		protected function set _input(value:Input):*
		{
			return _inputInner = value;
		}
		protected function get _fullScreen():Boolean
		{
			return _fullScreenInner;
		}
		protected function set _fullScreen(value:Boolean):*
		{
			return _fullScreenInner = value;
		}
		protected function get _screenWidth():int
		{
			return _screenWidthInner;
		}
		protected function set _screenWidth(value:int):*
		{
			return _screenWidthInner = value;
		}
		protected function get _screenHeight():int
		{
			return _screenHeightInner;
		}
		protected function set _screenHeight(value:int):*
		{
			return _screenHeightInner = value;
		}
		// what is it??
		protected function get _timeDelta():Number
		{
			return _timeDeltaInner;
		}
		protected function set _timeDelta(value:Number):*
		{
			return _timeDeltaInner = value;
		}
		
		
		public static function getInstance():CitrusEngine
		{
			return _instance;
		}
		
		/**
		 * Flash's innards should be calling this, because you should be extending your document class with it.
		 */		
		public function CitrusEngine()
		{
			_instance = this;
			
			onPlayingChange = new Signal(Boolean);
			onStageResize = new Signal(int, int);
			
			onPlayingChange.add(handlePlayingChange);
			
			// on iOS if the physical button is off, mute the sound
			if ("audioPlaybackMode" in SoundMixer)
				try { SoundMixer.audioPlaybackMode = "ambient"; }
					catch(e:ArgumentError) {
							trace("[CitrusEngine] could not set SoundMixer.audioPlaybackMode to ambient.");
						}
			
			//Set up console
			_console = new Console(9); //Opens with tab key by default
			_console.onShowConsole.add(handleShowConsole);
			_console.addCommand("set", handleConsoleSetCommand);
			_console.addCommand("get", handleConsoleGetCommand);
			addChild(_console);
			
			//timekeeping
			_gameTime = _startTime = new Date().time;
			
			//Set up input
			_input = new Input();
			
			//Set up sound manager
			_sound = SoundManager.getInstance();
			
			addEventListener(Event.ENTER_FRAME, handleEnterFrame);
			addEventListener(Event.ADDED_TO_STAGE, handleAddedToStage);
		}
		
		/**
		 * Called when CitrusEngine is added to the stage and ready to run.
		 */
		public function initialize():void {
		}
		
		/**
		 * Destroy the Citrus Engine, use it only if the Citrus Engine is just a part of your project and not your Main class.
		 */
		public function destroy():void {
			
			onPlayingChange.removeAll();
			onStageResize.removeAll();
			
			stage.removeEventListener(Event.ACTIVATE, handleStageActivated);
			stage.removeEventListener(Event.DEACTIVATE, handleStageDeactivated);
			stage.removeEventListener(FullScreenEvent.FULL_SCREEN, handleStageFullscreen);
			stage.removeEventListener(Event.RESIZE, handleStageResize);
			
			removeEventListener(Event.ENTER_FRAME, handleEnterFrame);
			
			if (_state) {
				
				_state.destroy();
				
				if (_state is State)
					removeChild(_state as State);
			}
				
			_console.destroy();
			removeChild(_console);
			
			_input.destroy();
			_sound.destroy();
		}
		
		/**
		 * Set up things that need the stage access.
		 */
		protected function handleAddedToStage(e:Event):void 
		{
			removeEventListener(Event.ADDED_TO_STAGE, handleAddedToStage);
			stage.scaleMode = StageScaleMode.NO_SCALE;
			stage.align = StageAlign.TOP_LEFT;
			stage.addEventListener(Event.DEACTIVATE, handleStageDeactivated);
			stage.addEventListener(Event.ACTIVATE, handleStageActivated);
			
			stage.addEventListener(FullScreenEvent.FULL_SCREEN, handleStageFullscreen);
			stage.addEventListener(Event.RESIZE, handleStageResize);
			
			_fullScreen = (stage.displayState == StageDisplayState.FULL_SCREEN || stage.displayState  == StageDisplayState.FULL_SCREEN_INTERACTIVE);
			resetScreenSize();
			
			_input.initialize();
			
			this.initialize();
		}
		
		protected function handleStageFullscreen(e:FullScreenEvent):void
		{
			_fullScreen = e.fullScreen;
		}
		
		protected function handleStageResize(e:Event):void
		{
			resetScreenSize();
			onStageResize.dispatch(_screenWidth, _screenHeight);
		}
		
		/**
		 * on resize or fullscreen this is called and makes sure _screenWidth/_screenHeight is correct,
		 * it can be overriden to update other values that depend on the values of _screenWidth/_screenHeight.
		 */
		protected function resetScreenSize():void
		{
			_screenWidth = stage.stageWidth;
			_screenHeight = stage.stageHeight;
		}
		
		/**
		 * called when the value of 'playing' changes.
		 * resets input actions , pauses/resumes all sounds by default.
		 */
		protected function handlePlayingChange(value:Boolean):void
		{
			if(input)
				input.resetActions();
			
			if (sound)
				if(value)
					sound.resumeAll();
				else
					sound.pauseAll();
		}
		
		/**
		 * This is the game loop. It switches states if necessary, then calls update on the current state.
		 */		
		//TODO The CE updates use the timeDelta to keep consistent speed during slow framerates. However, Box2D becomes unstable when changing timestep. Why?
		protected function handleEnterFrame(e:Event):void
		{
			//Change states if it has been requested
			if (_newState && _newState is State) {
					
				if (_state && _state is State) {
					
					_state.destroy();
					removeChild(_state as State);
				}
				
				_state = _newState;
				_newState = null;
				
				if (_futureState)
					_futureState = null;
						
				else {
					addChildAt(_state as State, _stateDisplayIndex);
					_state.initialize();
				}
							
			}
			
			if (_stateTransitionning && _stateTransitionning is State) {
					
				_futureState = _stateTransitionning;
				_stateTransitionning = null;
				
				addChildAt(_futureState as State, _stateDisplayIndex);
				_futureState.initialize();
			}
			
			//Update the state
			if (_state && _playing)
			{
				_nowTime = new Date().time;
				_timeDelta = (_nowTime - _gameTime) * 0.001;
				_gameTime = _nowTime;
				
				_state.update(_timeDelta);
				if (_futureState)
					_futureState.update(_timeDelta);
			}
			
			_input.citrus_internal::update();
			
		}
		
		/**
		 * Set CitrusEngine's playing to false. Every update methods aren't anymore called.
		 */
		protected function handleStageDeactivated(e:Event):void
		{
			playing = false;
		}
		
		/**
		 * Set CitrusEngine's playing to true. The main loop is performed.
		 */
		protected function handleStageActivated(e:Event):void
		{
			playing = true;
		}
		
		private function handleShowConsole():void
		{
			if (_input.enabled)
			{
				_input.enabled = false;
				_console.onHideConsole.addOnce(handleHideConsole);
			}
		}
		
		private function handleHideConsole():void
		{
			_input.enabled = true;
		}
		
		private function handleConsoleSetCommand(objectName:String, paramName:String, paramValue:String):void
		{
			var object:CitrusObject = _state.getObjectByName(objectName);
			
			if (!object)
			{
				trace("Warning: There is no object named " + objectName);
				return;
			}
			
			var value:Object;
			if (paramValue == "true")
				value = true;
			else if (paramValue == "false")
				value = false;
			else
				value = paramValue;
			
			if (object.hasOwnProperty(paramName))
				object[paramName] = value;
			else
				trace("Warning: " + objectName + " has no parameter named " + paramName + ".");
		}
		
		private function handleConsoleGetCommand(objectName:String, paramName:String):void
		{
			var object:CitrusObject = _state.getObjectByName(objectName);
			
			if (!object)
			{
				trace("Warning: There is no object named " + objectName);
				return;
			}
			
			if (object.hasOwnProperty(paramName))
				trace(objectName + " property:" + paramName + "=" + object[paramName]);	
			else
				trace("Warning: " + objectName + " has no parameter named " + paramName + ".");
		}
		
	}
}