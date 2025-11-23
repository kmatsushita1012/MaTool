//
//  Application.swift
//  MaToolAPI
//
//  Created by 松下和也 on 2025/10/27.
//

import Foundation
import AWSLambdaRuntime
import AWSLambdaEvents
import Shared



// MARK: - Application
final class Application: @unchecked Sendable {
    
    enum Method: String {
        case get = "GET"
        case put = "PUT"
        case post = "POST"
        case delete = "DELETE"
    }
    
    struct Request: Sendable {
        let method: Method?
        let path: String
        let headers: [String: String]
        var parameters: [String: String]
        var user: UserRole? = nil
        let body: String?
    }

    struct Response: Sendable {
        let statusCode: Int
        let headers: [String: String]
        let body: String
    }

    enum PathComponent: Sendable {
        case constant(String)
        case parameter(String)
    }

    struct Layer: Sendable {
        let method: Method?
        let path: [PathComponent]
        let middlewares: [Middleware]
    }
    
    typealias Handler = @Sendable (Request) async -> Response
    
    typealias Middleware = @Sendable (Request, Handler) async -> Response
    
    private var layers: [Layer] = []

    // --- Route registration (Express/Vapor style) ---
    func get(path: String,_ middlewares: Middleware...) {
        add(method: .get, path: path, middlewares: middlewares)
    }

    func post(path: String, _ middlewares: Middleware...) {
        add(method: .post, path: path, middlewares: middlewares)
    }

    func put(path: String, _ middlewares: Middleware...) {
        add(method: .put, path: path, middlewares: middlewares)
    }

    func delete(path: String, _ middlewares: Middleware...) {
        add(method: .delete, path: path, middlewares: middlewares)
    }
    
    func add(method: Method, path: String, middlewares: Middleware...) {
        add(method: method, path: path, middlewares: middlewares)
    }
    
    private func add(method: Method, path: String, middlewares: [Middleware]) {
        let components = path.split(separator: "/").map { p -> PathComponent in
            p.hasPrefix(":") ? .parameter(String(p.dropFirst())) : .constant(String(p))
        }
        layers.append(Layer(method: method, path: components, middlewares: middlewares))
    }
    
    func use(path: String = "/", _ middlewares: Middleware...) {
        use(path, middlewares)
    }
    
    private func use(_ path: String = "/", _ middlewares: [Middleware]) {
        let components = path.split(separator: "/").map { p -> PathComponent in
            p.hasPrefix(":") ? .parameter(String(p.dropFirst())) : .constant(String(p))
        }
        layers.append(Layer(method: nil, path: components, middlewares: middlewares))
    }

    func handle(_ request: Request) async -> Response {
        return await apply(layers)(request)
    }
    
    private func apply(_ layers: [Layer]) -> (Request) async -> Response {
        @Sendable func makeMiddlewareChain(_ middlewares: [Middleware], _ idx: Int, _ nextLayer: @escaping Handler) -> Handler {
            guard idx < middlewares.count else {
                return nextLayer
            }

            let current = middlewares[idx]
            return { req in
                await current(req) { nextReq in
                    await makeMiddlewareChain(middlewares, idx + 1, nextLayer)(nextReq)
                }
            }
        }

        @Sendable func makeLayerChain(_ index: Int) -> Handler {
            guard index < layers.count else {
                return { _ in Response(statusCode: 404, headers: [:], body: "Not Found") }
            }

            let layer = layers[index]
            return { req in
                guard layer.method == nil || layer.method == req.method,
                      let parameters = self.match(layer.path, req.path)
                else {
                    return await makeLayerChain(index + 1)(req)
                }
                
                var request = req
                request.parameters = parameters
                
                let nextLayer = makeLayerChain(index + 1)
                let middlewareChain = makeMiddlewareChain(layer.middlewares, 0, nextLayer)
                return await middlewareChain(request)
            }
        }

        return makeLayerChain(0)
    }


    private func match(_ route: [PathComponent], _ path: String) -> [String: String]? {
        let pathParts = path.split(separator: "/").map(String.init)
        guard route.count <= pathParts.count else { return nil }

        var params: [String: String] = [:]

        for (r, p) in zip(route, pathParts) {
            switch r {
            case .constant(let c) where c != p:
                return nil
            case .parameter(let name):
                params[name] = p
            default:
                continue
            }
        }
        return params
    }

}

extension Application {
    convenience init(@ApplicationBuilder _ content: () -> [Router]) {
        self.init()
        let layers = content()
        for layer in layers {
            layer.body(self)
        }
    }
}

@resultBuilder
enum ApplicationBuilder {
    static func buildBlock(_ components: Router...) -> [Router] {
        components
    }
}

extension Application.Response {
    private static func makeErrorResponse(title: String, detail: String, statusCode: Int) -> Self {
        let dict: [String: String] = [
            "title": title,
            "detail": detail
        ]
        let bodyData = try? JSONEncoder().encode(dict)
        let bodyString = bodyData.flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        
        return Self(
            statusCode: statusCode,
            headers: ["Content-Type": "application/json"],
            body: bodyString
        )
    }
    
    static func internalServerError(_ detail: String) -> Self {
        makeErrorResponse(title: "Internal Server Error", detail: detail, statusCode: 500)
    }    
}

