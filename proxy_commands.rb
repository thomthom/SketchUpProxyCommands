#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require 'sketchup.rb'

# Ensure older versions doesn't overwrite newer versions.
unless defined?(CommunityExtensions::ProxyCommands) &&
  CommunityExtensions::ProxyCommands.newer_than?('1.0.0') # <- Version of this file

module CommunityExtensions
  # @example
  #   validation = Proc.new { self.is_mode_active? }
  #   pc = CommunityExtensions::ProxyCommands
  #   pc.register(:move, validation) {
  #     Sketchup.active_model.select_tool(MyCustomMoveTool.new)
  #   }
  #   pc.register(:rotate, validation) {
  #     Sketchup.active_model.select_tool(MyCustomRotateTool.new)
  #   }
  #   pc.register(:scale, validation) {
  #     Sketchup.active_model.select_tool(MyCustomScaleTool.new)
  #   }
  #
  # @since 1.0.0
  module ProxyCommands

    # @since 1.0.0
    PLUGIN = self
    PLUGIN_ID = 'ProxyCommands'.freeze
    PLUGIN_NAME = 'Proxy Commands'.freeze
    PLUGIN_VERSION = '1.0.0'.freeze

    puts "Loading #{self} Version: #{PLUGIN_VERSION}"

    # @since 1.0.0
    unless defined?(ProxyCommand)
      ProxyCommand = Struct.new(:command, :validation_proc)
    end

    @registered ||= {}

    # Used by a load guard to ensure that older versions does not overwrite a
    # newer one. Part of this ProxyCommand API design is that newer versions
    # are required to be compatible with older versions.
    #
    # @param [String] version
    #
    # @return [Boolean]
    # @since 1.0.0
    def self.newer_than?(version)
      this_major, this_minor, this_revision = PLUGIN_VERSION.split('.')
      major, minor, revision = version.split('.')

      major = 0 if major.nil?
      minor = 0 if minor.nil?
      revision = 0 if revision.nil?

      return true if major < this_major
      if this_major == major
        return true if minor < this_minor
      end
      if this_minor == minor
        return true if revision < this_revision
      end
      false
    end

    # @param [Symbol] command_id
    # @param [Proc] proc
    #
    # @return [Boolean]
    # @since 1.0.0
    def self.register(command_id, validation, &proc)
      unless Commands.include?(command_id)
        raise ArgumentError, 'Invalid command ID.'
      end
      unless validation.is_a?(Proc)
        raise ArgumentError, '`validation` is not a valid Proc type.'
      end
      unless block_given?
        raise ArgumentError, "No block given."
      end
      @registered[command_id] ||= []
      if @registered[command_id].include?(proc)
        false
      else
        @registered[command_id] << ProxyCommand.new(proc, validation)
        true
      end
    end

    # Debugging method that clears all registered proxy commands.
    #
    # @return [Nil]
    # @since 1.0.0
    def self.clear!
      @registered.clear
      nil
    end

    # Internal method responsible for triggering the registered commands.
    #
    # @param [Symbol] command_id
    #
    # @return [Boolean]
    # @since 1.0.0
    def self.trigger(command_id)
      return false unless @registered[command_id]
      for command in @registered[command_id]
        if command.validation_proc.call
          command.command.call
          return true
        end
      end
      false
    end


    # @since 1.0.0
    module Commands

      if defined?(Sketchup::Set)
        Set = Sketchup::Set
      end

      @command_ids ||= Set.new

      # CommunityExtensions::ProxyCommands::Commands.command_ids
      #
      # @return [Array]
      # @since 1.0.0
      def self.command_ids
        @command_ids.to_a
      end

      # @param [Symbol] command_id
      #
      # @return [Boolean]
      # @since 1.0.0
      def self.include?(command_id)
        @command_ids.include?(command_id)
      end

      # Internal method to create UI::Command objects handling proxy commands.
      #
      # @param [Symbol] command_id
      # @param [String] title
      #
      # @return [UI::Command]
      # @since 1.0.0
      def self.proxy(command_id, title, &default)
        @command_ids.insert(command_id)
        UI::Command.new(title) {
          unless PLUGIN::trigger(command_id)
            default.call
          end
        }
      end

      ##### Edit ###############################################################

      # @since 1.0.0
      def self.undo
        self.proxy(:undo, 'Undo') {
          Sketchup.send_action('editUndo:')
        }
      end
      # @since 1.0.0
      def self.redo
        self.proxy(:redo, 'Redo') {
          Sketchup.send_action('editRedo:')
        }
      end

      # @since 1.0.0
      def self.cut
        self.proxy(:cut, 'Cut') {
          Sketchup.send_action('cut:')
        }
      end
      # @since 1.0.0
      def self.copy
        self.proxy(:copy, 'Copy') {
          Sketchup.send_action('copy:')
        }
      end
      # @since 1.0.0
      def self.paste
        self.proxy(:paste, 'Paste') {
          Sketchup.send_action('paste:')
        }
      end
      # @since 1.0.0
      def self.delete
        self.proxy(:delete, 'Delete') {
          Sketchup.send_action('editDelete:')
        }
      end

      # @since 1.0.0
      def self.select_all
        self.proxy(:select_all, 'Select All') {
          model = Sketchup.active_model
          model.selection.add(model.active_entities.to_a)
        }
      end
      # @since 1.0.0
      def self.select_none
        self.proxy(:select_none, 'Select None') {
          Sketchup.active_model.selection.clear
        }
      end
      # @since 1.0.0
      def self.invert_selection
        self.proxy(:invert_selection, 'Invert Selection') {
          model = Sketchup.active_model
          model.selection.toggle(model.active_entities.to_a)
        }
      end

      def self.hide
        self.proxy(:hide, 'Hide') {
          Sketchup.send_action('editHide:')
        }
      end
      def self.unhide
        self.proxy(:unhide, 'Unhide Selected') {
          Sketchup.send_action('editUnhide:')
        }
      end

      ##### Draw ###############################################################

      # @since 1.0.0
      def self.line_tool
        self.proxy(:line_tool, 'Line') {
          Sketchup.send_action('selectLineTool:')
        }
      end
      def self.arc_tool
        self.proxy(:arc_tool, 'Arc') {
          Sketchup.send_action('selectArcTool:')
        }
      end
      def self.freehand_tool
        self.proxy(:freehand_tool, 'Freehand') {
          Sketchup.send_action('selectFreehandTool:')
        }
      end

      def self.rectangle_tool
        self.proxy(:rectangle_tool, 'Rectangle') {
          Sketchup.send_action('selectRectangleTool:')
        }
      end
      def self.circle_tool
        self.proxy(:circle_tool, 'Circle') {
          Sketchup.send_action('selectCircleTool:')
        }
      end
      def self.polygon_tool
        self.proxy(:polygon_tool, 'Polygon') {
          Sketchup.send_action('selectPolygonTool:')
        }
      end


      ##### Tools ##############################################################

      # @since 1.0.0
      def self.select_tool
        self.proxy(:select_tool, 'Select') {
          Sketchup.send_action('selectSelectionTool:')
        }
      end
      # @since 1.0.0
      def self.erase_tool
        self.proxy(:eraser_tool, 'Eraser') {
          Sketchup.send_action('selectEraseTool:')
        }
      end
      # @since 1.0.0
      def self.paint_tool
        self.proxy(:paint_tool, 'Paint Bucket') {
          Sketchup.send_action('selectPaintTool:')
        }
      end

      # @since 1.0.0
      def self.move_tool
        self.proxy(:move_tool, 'Move') {
          Sketchup.send_action('selectMoveTool:')
        }
      end
      # @since 1.0.0
      def self.rotate_tool
        self.proxy(:rotate_tool, 'Rotate') {
          Sketchup.send_action('selectRotateTool:')
        }
      end
      # @since 1.0.0
      def self.scale_tool
        self.proxy(:scale_tool, 'Scale') {
          Sketchup.send_action('selectScaleTool:')
        }
      end

      # @since 1.0.0
      def self.pushpull_tool
        self.proxy(:pushpull_tool, 'Push/Pull') {
          Sketchup.send_action('selectPushPullTool:')
        }
      end
      # @since 1.0.0
      def self.followme_tool
        self.proxy(:followme_tool, 'Follow Me') {
          Sketchup.send_action('selectExtrudeTool:')
        }
      end
      # @since 1.0.0
      def self.offset_tool
        self.proxy(:offset_tool, 'Offset') {
          Sketchup.send_action('selectOffsetTool:')
        }
      end

      # @since 1.0.0
      def self.tapemeasure_tool
        self.proxy(:tapemeasure_tool, 'Tape Measure') {
          Sketchup.send_action('selectMeasureTool:')
        }
      end
      # @since 1.0.0
      def self.protractor_tool
        self.proxy(:protractor_tool, 'Protractor') {
          Sketchup.send_action('selectProtractorTool:')
        }
      end
      # @since 1.0.0
      def self.axes_tool
        self.proxy(:axes_tool, 'Axes') {
          Sketchup.send_action('selectAxisTool:')
        }
      end

      # @since 1.0.0
      def self.dimensions_tool
        self.proxy(:dimensions_tool, 'Dimensions') {
          Sketchup.send_action('selectDimensionTool:')
        }
      end
      # @since 1.0.0
      def self.text_tool
        self.proxy(:text_tool, 'Text') {
          Sketchup.send_action('selectTextTool:')
        }
      end
      # @since 1.0.0
      def self.text3d_tool
        self.proxy(:text3d_tool, '3D Text') {
          Sketchup.send_action('select3dTextTool:')
        }
      end

      # @since 1.0.0
      def self.sectionplane_tool
        self.proxy(:sectionplane_tool, 'Section Plane') {
          Sketchup.send_action('selectSectionPlaneTool:')
        }
      end
    end # module Commands


    # Menu manager ensuring that multiple menus is not created. It also makes
    # an effort to maintain menu ordering in case a newer version should be
    # loaded alongside an older version.
    #
    # If an old version is loaded after a new version then the old version will
    # not be doing anything. This is because new versions should be 100%
    # backwards compatible.
    #
    # If a newer version is loaded after an old version is loaded it will
    # attempt to insert new menu items in the correct order - provided the
    # SketchUp version it's being run on supports inserting menus at a given
    # index.
    #
    # Example:
    # One extensions loads a version 1.0 of the module.
    #   Version 1.0 loads the following menus:
    #   * :undo
    #   * :redo
    #   * :separator
    #   * :copy
    #   * :past
    #
    # Another extension loads version 1.2 of the module, it adds a new menu item
    # to the list.
    #   * :undo
    #   * :redo
    #   * :separator
    #   * :cut
    #   * :copy
    #   * :past
    #
    # If SketchUp doesn't support menus to be inserted at a given index the menu
    # list built will look like this:
    #   * :undo
    #   * :redo
    #   * :separator
    #   * :copy
    #   * :past
    #   * :cut
    #
    # But if SketchUp supports inserting at a given index then the new menu itme
    # will be inserted where it's intended:
    #   * :undo
    #   * :redo
    #   * :separator
    #   * :cut
    #   * :copy
    #   * :past
    #
    # @since 1.0.0
    module Menus

      # Root level menu where the menu tree is added.
      @root_menu ||= UI.menu('Plugins').add_submenu(PLUGIN_NAME)
      # Handles to top level sub-menus (Like Edit, Draw and Tools.)
      @top_menus ||= {}
      # List of existing menus built.
      @menus ||= {}
      # List of menu structure being built by this file.
      @last_menu ||= {}

      # Internal method ensuring duplicate top level menus are nor created.
      #
      # @param [Sketchup::Menu] menu
      #
      # @return [Boolean]
      # @since 1.0.0
      def self.get_top_menu(name)
        # Ensure there is only one menu per top level.
        @top_menus[name] ||= @root_menu.add_submenu(name)
        menu = @top_menus[name]
        # Reset the internal list of last menu items. This indicate a new
        # file is being loaded and the list will be used by that file.
        #
        # @last_menu is a list that is filled for the currently running file.
        #   It keeps track of the intended order of menus and use it to compare
        #   against the list of existing menus (@menus).
        @last_menu[menu] = []
        menu
      end

      # Internal method ensuring duplicate menu items are not created.
      #
      # @param [Sketchup::Menu] parent_menu
      # @param [Symbol] command_id Must correspond to a method under Commands.
      #
      # @return [Boolean]
      # @since 1.0.0
      def self.add_menu(parent_menu, command_id)
        unless Commands.respond_to?(command_id)
          raise ArgumentError, 'Invalid Command ID.'
        end
        # If the menu has already been added then don't add it again. But it
        # still needs to be added to the list (@last_menu) of commends processed
        # for this current file so the remaining menus can be inserted
        # correctly.
        @menus[parent_menu] ||= []
        if @menus[parent_menu].include?(command_id)
          @last_menu[parent_menu] << command_id
          return false
        end
        # Attempt to insert the menu items in the correct order if SketchUp
        # supports it.
        index = self.get_menu_index(parent_menu, command_id)
        if Sketchup::Menu.instance_method(:add_item).arity == 1
          parent_menu.add_item(Commands.send(command_id))
        else
          parent_menu.add_item(Commands.send(command_id), index)
        end
        # Menu is either inserted or appened at the end and the new menu item
        # is added to the list of current menus (@last_menu).
        @menus[parent_menu].insert(index, command_id)
        @last_menu[parent_menu] << command_id
        true
      end

      # Internal method ensuring duplicate menu separators are not created.
      #
      # @param [Sketchup::Menu] parent_menu
      # @param [Symbol] command_id
      #
      # @return [Boolean]
      # @since 1.0.0
      def self.add_separator(parent_menu)
        @menus[parent_menu] ||= []
        # Ensure two menu separators isn't added right after each other.
        previous_menu = @last_menu[parent_menu].last
        if @menus[parent_menu].last == :separator
          @last_menu[parent_menu] << :separator
          return false
        end
        # If the previous menu added was inserted and not appended at the end
        # then the separator isn't added either, because currently there is no
        # way to insert separators at a given index.
        previous_index = @menus[parent_menu].index(previous_menu)
        previous_max_index = @menus[parent_menu].length - 1
        unless previous_index == previous_max_index
          @last_menu[parent_menu] << :separator
          return false
        end
        # At this point we've ensured the separator can be added to the end of
        # the menu.
        parent_menu.add_separator
        @menus[parent_menu] << :separator
        @last_menu[parent_menu] << :separator
        true
      end

      # Internal method working out the correct insertion id for the menu item.
      #
      # @param [Sketchup::Menu] parent_menu
      # @param [Symbol] command_id
      #
      # @return [Integer]
      # @since 1.0.0
      def self.get_menu_index(parent_menu, command_id)
        previous_menu = @last_menu[parent_menu].last
        # Since separators cannot be identified from each other they need to be
        # treated with some extra care. When they are encountered the menu item
        # prior to the separator needs to be looked up in order to determine the
        # correct insertion order.
        previous_was_separator = previous_menu == :separator
        if previous_was_separator
          previous_menu = @last_menu[parent_menu][-2]
        end
        # Featch the index of the previous menu and increment accorcingly while
        # accounting for menu separators.
        previous_index = @menus[parent_menu].index(previous_menu)
        if previous_index
          # Insert into existing list.
          previous_index += 1
          previous_index += 1 if previous_was_separator
          previous_index
        else
          # Append to end.
          @menus[parent_menu].length
        end
      end

    end # module Menus


    unless file_loaded?( __FILE__ )
      m = Menus.get_top_menu('Edit')
      Menus.add_menu(m, :undo)
      Menus.add_menu(m, :redo)
      Menus.add_separator(m)
      Menus.add_menu(m, :cut)
      Menus.add_menu(m, :copy)
      Menus.add_menu(m, :paste)
      # (!) Missing: Paste In Place
      Menus.add_menu(m, :delete)
      Menus.add_separator(m)
      Menus.add_menu(m, :select_all)
      Menus.add_menu(m, :select_none)
      Menus.add_menu(m, :invert_selection)
      Menus.add_separator(m)
      Menus.add_menu(m, :hide)
      # (!) Missing: Unhide Last
      Menus.add_menu(m, :unhide)
      # (!) Missing: Unhide All

      m = Menus.get_top_menu('Draw')
      Menus.add_menu(m, :line_tool)
      Menus.add_menu(m, :arc_tool)
      Menus.add_menu(m, :freehand_tool)
      Menus.add_separator(m)
      Menus.add_menu(m, :rectangle_tool)
      Menus.add_menu(m, :circle_tool)
      Menus.add_menu(m, :polygon_tool)

      m = Menus.get_top_menu('Tools')
      Menus.add_menu(m, :select_tool)
      Menus.add_menu(m, :erase_tool)
      Menus.add_menu(m, :paint_tool)
      Menus.add_separator(m)
      Menus.add_menu(m, :move_tool)
      Menus.add_menu(m, :rotate_tool)
      Menus.add_menu(m, :scale_tool)
      Menus.add_separator(m)
      Menus.add_menu(m, :pushpull_tool)
      Menus.add_menu(m, :followme_tool)
      Menus.add_menu(m, :offset_tool)
      Menus.add_separator(m)
      Menus.add_menu(m, :tapemeasure_tool)
      Menus.add_menu(m, :protractor_tool)
      Menus.add_menu(m, :axes_tool)
      Menus.add_separator(m)
      Menus.add_menu(m, :dimensions_tool)
      Menus.add_menu(m, :text_tool)
      Menus.add_menu(m, :text3d_tool)
      Menus.add_separator(m)
      Menus.add_menu(m, :sectionplane_tool)
    end

  end # module ProxyCommands
end # module CommunityExtensions

end # Version Check

#-------------------------------------------------------------------------------

file_loaded( __FILE__ )

#-------------------------------------------------------------------------------
