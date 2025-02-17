extends PanelContainer

@onready var property_container = %VBoxContainer

var frames_per_second : String

#called upon instantiation into scene/tree
func _ready():
	
	#set the global reference to debug panel node
	Global.debug = self
	
	#make invisible upon creation in scene
	visible = false
	

func _process(delta):
	if visible:
		frames_per_second = "%.2f" % (1.0/delta)

func _input(event):
	if event.is_action_pressed("debug"):
		visible = !visible

func add_property(title: String, value, order):
	#hold new label node called everytime we call add property func
	var target
	target = property_container.find_child(title,true, false) #find label node with same title
	if !target: # if there is no current label node for property (initial load into debug panel)
		target = Label.new() #create new label
		property_container.add_child(target) #add new label to debug panel
		target.name = title # label name is passed in title
		target.text = target.name + ": " + str(value) # update text
	elif visible: #if already in panel we dont need to add it
		target.text = title + ": " + str(value) #update text
		property_container.move_child(target,order) #reorder properties based on given order value
