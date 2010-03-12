include Java
include_class "org.jruby.ruboto.RubotoActivity"
include_class "android.app.Activity"
include_class "android.content.Intent"
include_class "android.os.Bundle"
include_class "android.widget.Toast"
include_class "android.widget.ListView"
include_class "android.widget.Button"
include_class "android.widget.LinearLayout"
include_class "android.widget.EditText"
include_class "android.widget.TextView"

class Activity
  attr_accessor :init_block

  def start_ruboto_activity(remote_variable, &block)
    @@init_block = block

    if @initialized or not self.is_a?(RubotoActivity)
      b = Bundle.new
      b.putString("Remote Variable", remote_variable)
      b.putBoolean("Define Remote Variable", true)
      b.putString("Initialize Script", "#{remote_variable}.initialize_activity")

      i = Intent.new
      i.setClassName "org.jruby.ruboto.irb",  "org.jruby.ruboto.RubotoActivity"
      i.putExtra("RubotoActivity Config", b)

      self.startActivity i
    else
       instance_eval "#{remote_variable}=self"
      setRemoteVariable remote_variable
      initialize_activity
      on_create nil
    end

    self
  end

  def toast(text, duration=5000)
    Toast.makeText(self, text, duration).show
  end
  
  def toast_result(result, success, failure, duration=5000)
    toast(result ? success : failure, duration)
  end
end

class RubotoActivity
  #
  # Initialize
  #

  def initialize_activity()
    instance_eval &@@init_block 
    @initialized = true
    self
  end
  
  def on_create(bundle)
    setContentView(instance_eval &@content_view_block) if @content_view_block
  end
  
  def setup_content &block
    @content_view_block = block
  end

  #
  # Setup Callbacks
  #

  def self.create_callback(callback, parameters=[], additional_code="")
    class_eval "
      def handle_#{callback} &block
        requestCallback RubotoActivity::CB_#{callback.upcase}
        @#{callback}_block = block
      end
    
      def on_#{callback}(#{parameters.join(',')})
        #{additional_code}
        instance_eval {@#{callback}_block.call(#{parameters.join(',')})} if @#{callback}_block
      end
    "
  end

  create_callback :start
  create_callback :resume
  create_callback :restart
  create_callback :pause
  create_callback :stop
  create_callback :destroy
  create_callback :activity_result, [:intent]

  create_callback :save_instance_state, [:bundle]
  create_callback :restore_instance_state, [:bundle]
  create_callback :create_options_menu, [:menu], "@menu, @context_menu = menu, nil"
  create_callback :create_context_menu, [:menu, :view, :menu_info], "@menu, @context_menu = nil, menu"
  create_callback :item_click, [:adapter_view, :view, :pos, :item_id]
  create_callback :key, [:view, :key_code, :event]
  create_callback :editor_action, [:view, :action_id, :event]
  create_callback :click, [:view]

  #
  # Option Menus
  #

  def add_menu title, &block
    mi = @menu.add(title)
    mi.class.class_eval {attr_accessor :on_click}
    mi.on_click = block
  end
 
  def on_menu_item_selected(num,menu_item)
    instance_eval &(menu_item.on_click) if @menu
  end

  #
  # Context Menus
  #

  def add_context_menu title, &block
    mi = @context_menu.add(title)
    mi.class.class_eval {attr_accessor :on_click}
    mi.on_click = block
  end
 
  def on_context_item_selected(menu_item)
    (instance_eval {menu_item.on_click.call(menu_item.getMenuInfo.position)}) if menu_item.on_click
  end

  #
  # View Generation
  #

  @view_parent = nil

  def list_view(params={})
    @list = params[:list]
    rv = ListView.new self
    rv.setAdapter arrayAdapterForList(@list.to_java(:string))
    rv.setOnItemClickListener(self)
    @view_parent.addView(rv) if @view_parent
    rv
  end

  def text_view(params={})
    rv = TextView.new self
    rv.setText params[:text] if params[:text]
    @view_parent.addView(rv) if @view_parent
    rv
  end

  def edit_text(params={})
    rv = EditText.new self
    rv.setText params[:text] if params[:text]
    @view_parent.addView(rv) if @view_parent
    rv
  end

  def button(params={})
    rv = Button.new self
    rv.setOnClickListener self
    rv.setText params[:text] if params[:text]
    @view_parent.addView(rv) if @view_parent
    rv
  end

  def linear_layout(params={}, &block)
    rv = LinearLayout.new self
    rv.setOrientation params[:orientation] == :vertical ? LinearLayout::VERTICAL : LinearLayout::HORIZONTAL
    @view_parent.addView(rv) if @view_parent
    old_view_parent, @view_parent = @view_parent, rv
    yield block
    @view_parent = old_view_parent
    rv
  end
end