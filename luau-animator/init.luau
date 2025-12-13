-- Animator recreation in luau. Handles
-- animation blending, additive animations, priorities
-- built in!!

-- This is best used for procedual animations and having fine
-- grain control over animation playback. 
-- magicoal_nerb :3

local createAnimation = require("@self/createAnimation")
local AnimationTrack = require("@self/AnimationTrack")
local Animator = require("@self/Animator")
local Signal = require("@self/Signal")

export type AnimationSequence = createAnimation.AnimationSequence
export type AnimationPlayback = Animator.AnimationPlayback
export type AnimationTrack = AnimationTrack.AnimationTrack
export type Animator = Animator.Animator

export type Signal<T...> = Signal.Signal<T...>

return {
	-- main modules
	Animator = require("@self/Animator"),
	Tween = require("@self/Tween"),
	Queue = require("@self/Queue"),
	
	AnimationTrack = require("@self/AnimationTrack"),
	Signal = require("@self/Signal"),

	-- helper functions
	createAnimation = require("@self/createAnimation"),
	createAnimator = require("@self/replicator/createAnimator"),
}