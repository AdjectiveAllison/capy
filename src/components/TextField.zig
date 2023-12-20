const std = @import("std");
const backend = @import("../backend.zig");
const dataStructures = @import("../data.zig");
const internal = @import("../internal.zig");
const Size = dataStructures.Size;
const Atom = dataStructures.Atom;
const StringAtom = dataStructures.StringAtom;
const AtomicValue = if (@hasDecl(std.atomic, "Value")) std.atomic.Value else std.atomic.Atomic; // support zig 0.11 as well as current master

pub const TextField = struct {
    pub usingnamespace internal.All(TextField);
    //pub usingnamespace @import("internal.zig").Property(TextField, "text");

    peer: ?backend.TextField = null,
    widget_data: TextField.WidgetData = .{},
    text: StringAtom = StringAtom.of(""),
    readOnly: Atom(bool) = Atom(bool).of(false),
    _wrapperTextBlock: AtomicValue(bool) = AtomicValue(bool).init(false),

    pub fn init(config: TextField.Config) TextField {
        var field = TextField.init_events(TextField{
            .text = StringAtom.of(config.text),
            .readOnly = Atom(bool).of(config.readOnly),
        });
        field.setName(config.name);
        return field;
    }

    /// Internal function used at initialization.
    /// It is used to move some pointers so things do not break.
    pub fn _pointerMoved(self: *TextField) void {
        self.text.updateBinders();
    }

    /// When the text is changed in the StringAtom
    fn wrapperTextChanged(newValue: []const u8, userdata: usize) void {
        const self = @as(*TextField, @ptrFromInt(userdata));
        if (self._wrapperTextBlock.load(.Monotonic) == true) return;

        self.peer.?.setText(newValue);
    }

    fn wrapperReadOnlyChanged(newValue: bool, userdata: usize) void {
        const peer = @as(*?backend.TextField, @ptrFromInt(userdata));
        peer.*.?.setReadOnly(newValue);
    }

    fn textChanged(userdata: usize) void {
        const self = @as(*TextField, @ptrFromInt(userdata));
        const text = self.peer.?.getText();

        self._wrapperTextBlock.store(true, .Monotonic);
        defer self._wrapperTextBlock.store(false, .Monotonic);
        self.text.set(text);
    }

    pub fn show(self: *TextField) !void {
        if (self.peer == null) {
            var peer = try backend.TextField.create();
            peer.setText(self.text.get());
            peer.setReadOnly(self.readOnly.get());
            self.peer = peer;

            try self.show_events();
            try peer.setCallback(.TextChanged, textChanged);
            _ = try self.text.addChangeListener(.{ .function = wrapperTextChanged, .userdata = @intFromPtr(self) });
            _ = try self.readOnly.addChangeListener(.{ .function = wrapperReadOnlyChanged, .userdata = @intFromPtr(&self.peer) });
        }
    }

    pub fn getPreferredSize(self: *TextField, available: Size) Size {
        _ = available;
        if (self.peer) |peer| {
            return peer.getPreferredSize();
        } else {
            return Size{ .width = 200.0, .height = 40.0 };
        }
    }

    pub fn setText(self: *TextField, text: []const u8) void {
        self.text.set(text);
    }

    pub fn getText(self: *TextField) []const u8 {
        return self.text.get();
    }

    pub fn setReadOnly(self: *TextField, readOnly: bool) void {
        self.readOnly.set(readOnly);
    }

    pub fn isReadOnly(self: *TextField) bool {
        return self.readOnly.get();
    }
};

pub fn textField(config: TextField.Config) TextField {
    return TextField.init(config);
}
