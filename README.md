# VehMocap

Vehicle Motion Capture (VehMocap for short) is a MTA:SA resource for capturing the movement of vehicles ingame as animation and saving it as JSON files that can be used to playback said animation in 3D software (such as Blender) or within MTA:SA itself.


At the current development state, only the recording of standard cars being driven by the player is supported.


## Instalation and use:

[Download](https://github.com/ThePortuguesePlayer/VehMocap/archive/refs/heads/main.zip) and move the VehMocap folder to your MTA:SA instalation directory, under "./server/mods/deathmatch/resources".
Optionally, rename the folder to "vehmocap" (all lowercase) for easy of use.
Upon starting the resource, a notification will appear on your client's chat window. 
You can toggle the capture on and off while inside a vehicle by pressing \* on your numpad or using the command /s.
JSON files holding the captured data will be exported to the resource directory under "./captures".