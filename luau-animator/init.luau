-- Animator recreation in luau. Handles
-- animation blending, additive animations, priorities
-- built in!!

-- This is best used for procedual animations and having fine
-- grain control over animation playback. 
-- magicoal_nerb :3

local createAnimation = require("@self/createAnimation")
local Animator = require("@self/Animator")

export type AnimationTrack = createAnimation.AnimationTrack

export type AnimationPlayback = Animator.AnimationPlayback
export type Animator = Animator.Animator

return {
	-- main modules
	Animator = require("@self/Animator"),
	Tween = require("@self/Tween"),
	Queue = require("@self/Queue"),

	-- helper function
	createAnimation = require("@self/createAnimation"),
}