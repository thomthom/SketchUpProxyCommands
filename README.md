SketchUp Proxy Commands
=======================

***

Module Status: Draft (Work in Progress!)
----------------------------------------

This module needs review and testing! Please hold distribution until design has
been proven to work. But do share your thoughts.

**Do not redistribute!**

***

The purpose of this module is to create an interface where extensions that offer
alternative modelling toolsets can hook into and use the keyboard shortcuts for
the native tools.

For instance, I developed an extension Vertex Tools that offered a toolset to
manipulate vertices in SketchUp. It reproduced many of the native tools such as
Move, Rotate and Scale to work with vertices. These replacement tools created
an alternative modelling environment, but a big workflow obstacle was that the
user could not use the same shortcuts for the native commands for the mirroring
vertex commands. It was awkward to create all new keyboard shortcuts just for
the vertex tools.

The solution I made was to develop proxy tools and mapped the shortcuts to these
commands. If the user invoked the keyboard shortcut for Move and Vertex Tools
was active then Vertex Tools' Move tool would be active - otherwise the nativ
Move tool would be used. This allowed for seamless worflow integration.

This module is a scalable version where any extension can hook up their
alternative counterpart to the native SketchUp commands.

Example
-------

```ruby
# This proc should evaluate to true when the alternative replacement tool
# is in a state where it can be activated.
validation = Proc.new { self.is_mode_active? }

proxy = CommunityExtensions::ProxyCommands

proxy.register(:move_tool, validation) {
  Sketchup.active_model.select_tool(MyCustomMoveTool.new)
}
proxy.register(:rotate_tool, validation) {
  Sketchup.active_model.select_tool(MyCustomRotateTool.new)
}
proxy.register(:scale_tool, validation) {
  Sketchup.active_model.select_tool(MyCustomScaleTool.new)
}
```

Under the Hood
--------------

The module creates a set of menus for each command supported. The user can then
assign keyboard shortcuts to these menus.

When the command is invoked, either by accessing the menu or triggering the 
keyboard shortcut the module will iterate each registered alternative for that
command. It queries a validation proc which should return `true` or `false`.

If the validation proc returns true it indicates that it is ready to be called.
For instance, if Vertex Tools registered commands for Move, Rotate and Scale it
would return `true` in the validation proc is vertex editing mode was active.

It will keep iterating the list until it gets a reply the evaluates to `true`.
If a proxy command returns true then no other command will be evaluated. It's a
first come first serve deal.

If there is no proxy commands that responds then the native SketchUp behaviour
will be triggered.

Available Commands
------------------

To list available commands:
`CommunityExtensions::ProxyCommands::Commands.command_ids`

Bundling
--------

This package is designed to be dropped into any other package and loaded without
further modification to the `proxy_commands.rb` file. It has load guards that
will prevent older versions from overwriting newer versions. This off course
depends entirely that newer versions are made to be 100% backwards compatible.

Extending
---------

In order to ensure things do not break it is important that when adding new
commands that the names and design of this module is not changed.

1. Add new commands to the ´Commands´ module.
2. Hook it up to a menu.
3. Bump the minor version number. (Bump the revision number only for bug fixes.)
4. Make a pull request back to the main repository.
   (https://github.com/thomthom/SketchUpProxyCommands)
5. Once accepted, you can integrate and bundle the new extended version.