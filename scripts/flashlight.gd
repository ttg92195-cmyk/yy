extends SpotLight3D
## Flashlight - Player's flashlight with battery system
## Attached to Flashlight SpotLight3D node in Player scene

var is_on: bool = true
var battery_percent: float = 100.0
var drain_rate: float = 2.0  ## % per second
var recharge_rate: float = 5.0  ## % per second when off
var flicker_threshold: float = 15.0  ## Start flickering below this %
var min_energy: float = 0.3
var max_energy: float = 2.5
var flicker_timer: float = 0.0
var flicker_speed: float = 15.0

# Light properties
var base_range: float = 20.0
var base_angle: float = 40.0
var base_attenuation: float = 0.5

# References
@onready var battery_ui: ProgressBar = null  ## Set by UI system


func _ready():
        light_energy = max_energy
        spot_range = base_range
        spot_angle = base_angle
        spot_attenuation = base_attenuation
        shadow_enabled = false
        shadow_bias = 0.05


func _process(delta):
        if not is_on:
                # Recharge when off
                battery_percent = min(100.0, battery_percent + recharge_rate * delta)
                # Update GameManager
                GameManager.flashlight_battery = battery_percent
                return

        # Drain battery
        battery_percent = max(0.0, battery_percent - drain_rate * delta)
        GameManager.flashlight_battery = battery_percent

        # Battery empty - turn off
        if battery_percent <= 0.0:
                turn_off()
                return

        # Update light energy based on battery
        light_energy = lerp(min_energy, max_energy, battery_percent / 100.0)

        # Flicker effect when battery is low
        if battery_percent < flicker_threshold:
                flicker_timer += delta * flicker_speed
                var flicker = sin(flicker_timer) * cos(flicker_timer * 1.5)
                light_energy += flicker * 0.5

                # Random chance to temporarily cut out
                if randf() < 0.01:
                        light_energy = 0.0
                        await get_tree().create_timer(0.1).timeout
                        light_energy = lerp(min_energy, max_energy, battery_percent / 100.0)

        # Update UI
        if battery_ui:
                battery_ui.value = battery_percent


func toggle():
        if battery_percent <= 0.0 and not is_on:
                return  ## Can't turn on with dead battery

        is_on = !is_on
        visible = is_on

        if is_on:
                # Play click-on sound
                _play_click_sound()
        else:
                # Play click-off sound
                _play_click_sound()


func turn_off():
        is_on = false
        visible = false
        _play_click_sound()


func turn_on():
        if battery_percent <= 0.0:
                return
        is_on = true
        visible = true
        _play_click_sound()


func _play_click_sound():
        ## Play flashlight click sound effect
        # TODO: Add audio stream
        pass


func get_battery_percent() -> float:
        return battery_percent


func is_flashlight_on() -> bool:
        return is_on
