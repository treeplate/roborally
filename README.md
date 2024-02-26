# RoboRally - the video game
Players: 2+<br>
<br>
This is a game (based on [this board game](https://en.wikipedia.org/wiki/RoboRally)) where you control a robot trying to navigate through a maze to get to flags.<br>
## Materials needed
1 phone/tablet/laptop per player ("client devices")<br>
1 tablet/laptop/desktop (the "server device")<br>

## Before the game
Create a file called `servers.cfg` with each line following this format:
```
<server ip> <server name>
```
Server IP is the IP of the server device.<br>
Server Name is what you want to call this server device.<br>
<br>
Install [Flutter](https://docs.flutter.dev/get-started) on a computer. 
In the `roborally_client` folder, 
use `flutter run` to install the client on all the client devices.<br>

## Game setup
In the `roborally_server` directory, run `flutter run` to run the server on the server device.<br>

### Server device instructions
Pick a board, some number of flags, and then drag the flags onto the board and then press "Ready". You don't need to do anything else on the server device, but it should still be visible to everyone playing.
### Client device instructions
Launch the `roborally_client` app. Select the server device from the list of devices in the app, and press "Join". Pick a name and a robot, and then press "Ready".

## During the game
[This document](https://docs.google.com/document/d/14qW9BK9GCU-Qn23bxzlLt_nyWVvkkI0DYJzm_94JgFk/edit?usp=sharing) explains how to play the game.