const std = @import("std");
const shared_mod = @import("shared_mod");
const zinc = @import("zinc");

pub fn main() !void {
    var z = try zinc.init(.{
        .addr = "0.0.0.0",
        .port = shared_mod.port,
        .num_threads = shared_mod.thread_count,
        .max_conn = shared_mod.connection_count,
        .read_buffer_len = 8192,
        .header_buffer_len = 1024,
        .body_buffer_len = 4096,
        .stack_size = 1024 * 1024,
        // io_uring needs a power of two; zinc clamps this to 4095.
        .aio_queue_depth = 2048,
    });
    defer z.deinit();

    var router = z.getRouter();
    try router.get("/", root);
    try router.get("/httpz", httpz);
    try router.get("/api/users", users);
    try router.post("/form", form);
    try router.post("/upload", upload);

    std.debug.print("Started on port {d}\n", .{shared_mod.port});
    try z.run();
}

fn root(ctx: *zinc.Context) anyerror!void {
    try ctx.text(shared_mod.response.hello_world, .{});
}

fn httpz(ctx: *zinc.Context) anyerror!void {
    try ctx.text("OK", .{});
}

fn users(ctx: *zinc.Context) anyerror!void {
    try ctx.json(shared_mod.response.users, .{});
}

fn form(ctx: *zinc.Context) anyerror!void {
    const body = ctx.getBody() orelse "";
    if (std.mem.indexOf(u8, body, "name=") == null) {
        try ctx.text("missing name", .{});
        return;
    }
    try ctx.text("OK", .{});
}

fn upload(ctx: *zinc.Context) anyerror!void {
    const body = ctx.getBody() orelse "";
    if (std.mem.indexOf(u8, body, "filename=") == null) {
        try ctx.text("missing file", .{});
        return;
    }
    try ctx.text("OK", .{});
}
