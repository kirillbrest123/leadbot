![LeadBot](https://repository-images.githubusercontent.com/188332969/93320b00-7d8a-11e9-95ab-8ec570917423)
# Leadbot fork for Deathmatch: Unlimited
#### Current State: Alpha
### Installation
Click "Code" -> Download ZIP -> Extract leadbot-master to /addons/
### Commands/Convars
 - leadbot_add _[1-128]_
 - leadbot_afk
 - leadbot_kick _[name/all]_
 - leadbot_quota _[0-128]_
 - leadbot_strategy _[0/1]_
 - leadbot_afk_timetoafk _[0-300]_
 - leadbot_fakeping _[0/1]_ *Using this outside of Singleplayer/LAN/nomaster servers could get you banned/blacklisted!*
 - leadbot_name_prefix _[prefix]_
 - leadbot_names _[name1,name2]_
 - leadbot_voice _[voiceset]_
 - leadbot_fov _[75-100]_
 - leadbot_skill _[0-3]_
### Chat commands
 - !botskill _[0-3]_ - Initiate a vote to change bots' skill level
 - !botquota _[0-*max players-1*]_ - Initiate a vote to change bot quota
### Notable changes
 - Bots have 4 different skill levels: Easy, Normal, Hard, Aggressive. They determine things like how fast bots aim, how frequently they jump, how fast they forget their target, etc
 - Bots don't have infinite ammo
 - Bots will choose their weapon depending on its rarity and ammo
 - Bots will go towards weapon, health, armor pick-ups if they are close enough and have LoS
 - Bots will go towards entities from `DMU.BotObjectves` and `DMU.BotTeamObjectives[*bot's team*]`. Add your objective entities to these tables to make bots go towards them
 - Bots will not back down from their target if their active weapon has `SWEP.Melee` set to true
