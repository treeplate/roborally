# RoboRally - the video game
Players: 2+<br>
<br>
This is a game (based on [this board game](https://en.wikipedia.org/wiki/RoboRally)) where you control a robot trying to navigate through a maze to get to flags.<br>
## Materials needed
1 phone/tablet/laptop per player ("client devices")<br>
1 tablet/laptop/desktop (the "server device")<br>

## Before the game
Create a file called `servers.cfg` in `roborally_client` with each line following this format:
```
<server ip> <server name>
```
Server IP is the IP of the server device.<br>
Server Name is what you want to call this server device.<br>
When running the client, each line will be a server device you can connect to.
<br>
Install [Flutter](https://docs.flutter.dev/get-started) on a computer. 
In the `roborally_client` folder, 
use `flutter run` to install the client on all the client devices.<br>

## Game setup
In the `roborally_server` directory, run `flutter run` to run the server on the server device.<br>

### Server device instructions
Pick a board, and then drag as many flags as you want onto the board and then press "Done". You don't need to do anything else on the server device, but it should still be visible to everyone playing.
### Client device instructions
Launch the `roborally_client` app. Select the server device from the list of devices in the app. Pick a name and a color, and then press "Join Server".

## During the game
[This document](https://docs.google.com/document/d/14qW9BK9GCU-Qn23bxzlLt_nyWVvkkI0DYJzm_94JgFk/edit?usp=sharing) explains how to play the game. It may be helpful to have printed out.