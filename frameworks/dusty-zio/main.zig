const std = @import("std");
const shared_mod = @import("shared_mod");
const http = @import("dusty");
const zio = @import("zio");

pub fn main(init: std.process.Init) !void {
    var rt = try zio.Runtime.init(init.gpa, .{
        .executors = .exact(shared_mod.thread_count),
    });
    defer rt.deinit();

    const listeners = [_]http.Listener{.{
        .address = .{ .ip = try std.Io.net.IpAddress.parse("0.0.0.0", shared_mod.port) },
        .reuse_address = true,
        .kernel_backlog = shared_mod.connection_count,
    }};

    var server = http.Server(void).init(init.gpa, rt.io(), .{
        .max_connections = shared_mod.connection_count,
        .listeners = &listeners,
        .timeout = .{
            .request = null,
            .keepalive = null,
        },
    }, {});
    defer server.deinit();

    server.router.get("/", root);
    server.router.get("/httpz", plaintext);
    server.router.get("/api/users", users);
    server.router.get("/api/users/:id", user);
    server.router.post("/form", form);
    server.router.post("/upload", upload);

    std.debug.print("Started on port {d} (zio, {d} threads)\n", .{ shared_mod.port, shared_mod.thread_count });
    try server.run();
}

fn root(_: *http.Request, res: *http.Response) !void {
    res.status = .ok;
    res.body = shared_mod.response.hello_world;
}

fn plaintext(_: *http.Request, res: *http.Response) !void {
    res.status = .ok;
    res.body = "OK";
}

fn users(_: *http.Request, res: *http.Response) !void {
    res.status = .ok;
    try res.json(shared_mod.response.users, .{});
}

fn user(req: *http.Request, res: *http.Response) !void {
    const id = std.fmt.parseInt(u32, req.params.get("id") orelse "0", 10) catch 0;

    if (id == 0 or id > shared_mod.response.users.len) {
        res.status = .bad_request;
        try res.json(.{ .message = "Invalid ID" }, .{});
        return;
    }

    res.status = .ok;
    try res.json(shared_mod.response.users[id - 1], .{});
}

fn form(req: *http.Request, res: *http.Response) !void {
    const data = try req.formData();
    if (data.get("name") == null) {
        res.status = .bad_request;
        res.body = "missing name";
        return;
    }
    res.status = .ok;
    res.body = "OK";
}

fn upload(req: *http.Request, res: *http.Response) !void {
    const data = try req.multiFormData();
    const file = data.get("file") orelse {
        res.status = .bad_request;
        res.body = "missing file";
        return;
    };
    if (file.filename == null) {
        res.status = .bad_request;
        res.body = "missing filename";
        return;
    }
    res.status = .ok;
    res.body = "OK";
}
