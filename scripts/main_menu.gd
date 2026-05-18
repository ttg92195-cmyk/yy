extends Control
## MainMenu - Main menu UI with Host/Join/AI Ghost game options

@onready var host_button: Button = $VBoxContainer/HostButton
@onready var join_button: Button = $VBoxContainer/JoinButton
@onready var ai_ghost_button: Button = $VBoxContainer/AIGhostButton
@onready var settings_button: Button = $VBoxContainer/SettingsButton
@onready var quit_button: Button = $VBoxContainer/QuitButton

@onready var join_panel: Panel = $JoinPanel
@onready var ip_input: LineEdit = $JoinPanel/VBoxContainer/IPInput
@onready var name_input: LineEdit = $JoinPanel/VBoxContainer/NameInput
@onready var connect_button: Button = $JoinPanel/VBoxContainer/ConnectButton
@onready var back_button: Button = $JoinPanel/VBoxContainer/BackButton

@onready var host_panel: Panel = $HostPanel
@onready var host_name_input: LineEdit = $HostPanel/VBoxContainer/NameInput
@onready var start_button: Button = $HostPanel/VBoxContainer/StartButton
@onready var host_back_button: Button = $HostPanel/VBoxContainer/BackButton
@onready var player_list: VBoxContainer = $HostPanel/VBoxContainer/PlayerList

@onready var status_label: Label = $StatusLabel
@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var version_label: Label = $VersionLabel


func _ready():
        # Connect button signals
        host_button.pressed.connect(_on_host_pressed)
        join_button.pressed.connect(_on_join_pressed)
        ai_ghost_button.pressed.connect(_on_ai_ghost_pressed)
        settings_button.pressed.connect(_on_settings_pressed)
        quit_button.pressed.connect(_on_quit_pressed)

        connect_button.pressed.connect(_on_connect_pressed)
        back_button.pressed.connect(_on_back_from_join)
        start_button.pressed.connect(_on_start_game)
        host_back_button.pressed.connect(_on_back_from_host)

        # Connect network signals
        NetworkManager.player_connected.connect(_on_player_connected)
        NetworkManager.player_disconnected.connect(_on_player_disconnected)
        NetworkManager.connection_failed.connect(_on_connection_failed)
        NetworkManager.server_disconnected.connect(_on_server_disconnected)

        # Initial UI state
        join_panel.visible = false
        host_panel.visible = false
        status_label.text = ""

        # Default values
        ip_input.text = "127.0.0.1"
        name_input.text = "Player"
        host_name_input.text = "Host"

        # Style
        title_label.text = "THE GHOST"
        version_label.text = "v0.1.0 - Alpha"


func _on_host_pressed():
        """Show the host game panel"""
        $VBoxContainer.visible = false
        host_panel.visible = true

        # Start hosting
        var player_name = host_name_input.text
        if player_name == "":
                player_name = "Host"

        if NetworkManager.host_game(player_name):
                status_label.text = "Server started! Waiting for players..."
                GameManager.enter_lobby()
        else:
                status_label.text = "Failed to start server!"


func _on_join_pressed():
        """Show the join game panel"""
        $VBoxContainer.visible = false
        join_panel.visible = true


func _on_ai_ghost_pressed():
        """Start a local game with AI ghost (single player / LAN practice)"""
        status_label.text = "Loading game..."
        # Change to game scene which handles AI ghost automatically
        get_tree().change_scene_to_file("res://scenes/game.tscn")


func _on_connect_pressed():
        """Connect to a host server"""
        var address = ip_input.text
        var player_name = name_input.text

        if address == "":
                status_label.text = "Please enter an IP address!"
                return
        if player_name == "":
                player_name = "Player"

        if NetworkManager.join_game(address, player_name):
                status_label.text = "Connecting to %s..." % address
                GameManager.enter_lobby()
        else:
                status_label.text = "Failed to connect!"


func _on_start_game():
        """Start the game (host only)"""
        var player_count = NetworkManager.get_player_count()
        if player_count < 2:
                # Not enough real players - offer AI ghost
                status_label.text = "Not enough players! Starting with AI ghost..."
                NetworkManager.start_game_ai_ghost()
        else:
                NetworkManager.start_game()


func _on_back_from_join():
        """Return to main menu from join panel"""
        join_panel.visible = false
        $VBoxContainer.visible = true
        status_label.text = ""


func _on_back_from_host():
        """Return to main menu from host panel"""
        NetworkManager.disconnect_game()
        host_panel.visible = false
        $VBoxContainer.visible = true
        status_label.text = ""


func _on_player_connected(peer_id: int, player_info: Dictionary):
        """Update player list when someone connects"""
        status_label.text = "Player connected: %s" % player_info.get("player_name", "Unknown")
        _update_player_list()


func _on_player_disconnected(_peer_id: int):
        """Update player list when someone disconnects"""
        status_label.text = "Player disconnected"
        _update_player_list()


func _on_connection_failed():
        """Handle connection failure"""
        status_label.text = "Connection failed! Check IP and try again."
        join_panel.visible = false
        $VBoxContainer.visible = true


func _on_server_disconnected():
        """Handle server disconnection"""
        status_label.text = "Disconnected from server!"
        host_panel.visible = false
        join_panel.visible = false
        $VBoxContainer.visible = true


func _update_player_list():
        """Update the player list in the host panel"""
        # Clear existing list
        for child in player_list.get_children():
                child.queue_free()

        # Add all players
        for pid in NetworkManager.players:
                var info = NetworkManager.players[pid]
                var label = Label.new()
                label.text = "%s (ID: %d) - %s" % [info.player_name, info.peer_id, info.role]
                player_list.add_child(label)


func _on_settings_pressed():
        """Open settings menu"""
        $VBoxContainer.visible = false
        if has_node("SettingsPanel"):
                $SettingsPanel.visible = true
        else:
                status_label.text = "Settings coming soon!"


func _on_quit_pressed():
        """Quit the game"""
        get_tree().quit()
