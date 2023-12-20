const std = @import("std");
const backend = @import("../backend.zig");
const internal = @import("../internal.zig");
const Size = @import("../data.zig").Size;
const Atom = @import("../data.zig").Atom;
const Widget = @import("../widget.zig").Widget;
const AtomicValue = if (@hasDecl(std.atomic, "Value")) std.atomic.Value else std.atomic.Atomic; // support zig 0.11 as well as current master

pub const Alignment = struct {
    pub usingnamespace @import("../internal.zig").All(Alignment);

    peer: ?backend.Container = null,
    widget_data: Alignment.WidgetData = .{},

    child: Widget,
    relayouting: AtomicValue(bool) = AtomicValue(bool).init(false),
    x: Atom(f32) = Atom(f32).of(0.5),
    y: Atom(f32) = Atom(f32).of(0.5),

    pub fn init(config: Alignment.Config, widget: Widget) !Alignment {
        var component = Alignment.init_events(Alignment{ .child = widget });
        component.x.set(config.x);
        component.y.set(config.y);
        try component.addResizeHandler(&onResize);

        return component;
    }

    pub fn _pointerMoved(self: *Alignment) void {
        self.x.updateBinders();
        self.y.updateBinders();
    }

    pub fn onResize(self: *Alignment, _: Size) !void {
        self.relayout();
    }

    pub fn getChild(self: *Alignment, name: []const u8) ?*Widget {
        if (self.child.name.*.get()) |child_name| {
            if (std.mem.eql(u8, child_name, name)) {
                return &self.child;
            }
        }
        return null;
    }

    /// When alignX or alignY is changed, this will trigger a parent relayout
    fn alignChanged(_: f32, userdata: usize) void {
        const self = @as(*Alignment, @ptrFromInt(userdata));
        self.relayout();
    }

    pub fn _showWidget(widget: *Widget, self: *Alignment) !void {
        self.child.parent = widget;
        self.child.class.setWidgetFn(&self.child);
    }

    pub fn show(self: *Alignment) !void {
        if (self.peer == null) {
            var peer = try backend.Container.create();
            self.peer = peer;

            _ = try self.x.addChangeListener(.{ .function = alignChanged, .userdata = @intFromPtr(self) });
            _ = try self.y.addChangeListener(.{ .function = alignChanged, .userdata = @intFromPtr(self) });

            self.child.class.setWidgetFn(&self.child);
            try self.child.show();
            peer.add(self.child.peer.?);

            try self.show_events();
        }
    }

    pub fn relayout(self: *Alignment) void {
        if (self.relayouting.load(.SeqCst) == true) return;
        if (self.peer) |peer| {
            self.relayouting.store(true, .SeqCst);
            defer self.relayouting.store(false, .SeqCst);

            const available = Size{ .width = @as(u32, @intCast(peer.getWidth())), .height = @as(u32, @intCast(peer.getHeight())) };

            const alignX = self.x.get();
            const alignY = self.y.get();

            if (self.child.peer) |widgetPeer| {
                const preferredSize = self.child.getPreferredSize(available);
                const finalSize = Size.intersect(preferredSize, available);

                const x = @as(u32, @intFromFloat(alignX * @as(f32, @floatFromInt(available.width -| finalSize.width))));
                const y = @as(u32, @intFromFloat(alignY * @as(f32, @floatFromInt(available.height -| finalSize.height))));

                peer.move(widgetPeer, x, y);
                peer.resize(widgetPeer, finalSize.width, finalSize.height);
            }
        }
    }

    pub fn getPreferredSize(self: *Alignment, available: Size) Size {
        return self.child.getPreferredSize(available);
    }

    pub fn _deinit(self: *Alignment) void {
        self.child.deinit();
    }
};

pub fn alignment(opts: Alignment.Config, child: anytype) anyerror!Alignment {
    const element =
        if (comptime internal.isErrorUnion(@TypeOf(child)))
        try child
    else
        child;

    const widget = try internal.genericWidgetFrom(element);
    return try Alignment.init(opts, widget);
}
