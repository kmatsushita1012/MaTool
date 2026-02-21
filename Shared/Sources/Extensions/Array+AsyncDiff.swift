//
//  Extensions.swift
//  matool-shared
//
//  Created by 松下和也 on 2026/01/09.
//

public extension Array where Element: Identifiable & Equatable & Sendable {

    func diff(
        with new: [Element],
        separateDeleteAndUpdate: Bool = false,
        onAdd: @Sendable @escaping (Element) async throws -> Element,
        onUpdate: @Sendable @escaping (Element) async throws -> Element,
        onDelete: @Sendable @escaping (Element) async throws -> Void
    ) async throws -> [Element] {

        let oldDict = Dictionary(uniqueKeysWithValues: self.map { ($0.id, $0) })
        let newDict = Dictionary(uniqueKeysWithValues: new.map { ($0.id, $0) })

        let results: [Result<Element, Error>]
        if separateDeleteAndUpdate {
            results = try await diffTwoPhase(
                old: self,
                new: new,
                oldDict: oldDict,
                newDict: newDict,
                onAdd: onAdd,
                onUpdate: onUpdate,
                onDelete: onDelete
            )
        } else {
            results = await diffSinglePhase(
                old: self,
                new: new,
                oldDict: oldDict,
                newDict: newDict,
                onAdd: onAdd,
                onUpdate: onUpdate,
                onDelete: onDelete
            )
        }

        let errors = results.compactMap {
            if case .failure(let err) = $0 { return err.localizedDescription }
            return nil
        }

        if !errors.isEmpty {
            throw DomainError.unknown(errors.joined(separator: "\n"))
        }

        return results.compactMap {
            if case .success(let item) = $0 { return item }
            return nil
        }
    }
    
    private func diffSinglePhase(
        old: [Element],
        new: [Element],
        oldDict: [Element.ID: Element],
        newDict: [Element.ID: Element],
        onAdd: @Sendable @escaping (Element) async throws -> Element,
        onUpdate: @Sendable @escaping (Element) async throws -> Element,
        onDelete: @Sendable @escaping (Element) async throws -> Void
    ) async -> [Result<Element, Error>]
    where Element: Identifiable & Equatable & Sendable {

        var results = [Result<Element, Error>]()

        await withTaskGroup(of: Result<Element, Error>?.self) { group in
            for newItem in new {
                if let oldItem = oldDict[newItem.id] {
                    if oldItem != newItem {
                        group.addTask {
                            do { return .success(try await onUpdate(newItem)) }
                            catch { return .failure(error) }
                        }
                    } else {
                        group.addTask { .success(oldItem) }
                    }
                } else {
                    group.addTask {
                        do { return .success(try await onAdd(newItem)) }
                        catch { return .failure(error) }
                    }
                }
            }

            for oldItem in old where newDict[oldItem.id] == nil {
                group.addTask {
                    do { try await onDelete(oldItem) }
                    catch { return .failure(error) }
                    return nil
                }
            }

            for await result in group {
                if let result = result {
                    results.append(result)
                }
            }
        }

        return results
    }
    
    private func diffTwoPhase(
        old: [Element],
        new: [Element],
        oldDict: [Element.ID: Element],
        newDict: [Element.ID: Element],
        onAdd: @Sendable @escaping (Element) async throws -> Element,
        onUpdate: @Sendable @escaping (Element) async throws -> Element,
        onDelete: @Sendable @escaping (Element) async throws -> Void
    ) async throws -> [Result<Element, Error>]
    where Element: Identifiable & Equatable & Sendable {

        var results = [Result<Element, Error>]()

        // --- Delete phase ---
        await withTaskGroup(of: Error?.self) { group in
            for oldItem in old where newDict[oldItem.id] == nil {
                group.addTask {
                    do {
                        try await onDelete(oldItem)
                        return nil
                    } catch {
                        return error
                    }
                }
            }

            for await error in group {
                if let error = error {
                    results.append(.failure(error))
                }
            }
        }

        if results.contains(where: {
            if case .failure = $0 { return true }
            return false
        }) {
            return results
        }

        // --- Add / Update phase ---
        await withTaskGroup(of: Result<Element, Error>.self) { group in
            for newItem in new {
                if let oldItem = oldDict[newItem.id] {
                    if oldItem != newItem {
                        group.addTask {
                            do { return .success(try await onUpdate(newItem)) }
                            catch { return .failure(error) }
                        }
                    } else {
                        group.addTask { .success(oldItem) }
                    }
                } else {
                    group.addTask {
                        do { return .success(try await onAdd(newItem)) }
                        catch { return .failure(error) }
                    }
                }
            }

            for await result in group {
                results.append(result)
            }
        }

        return results
    }
}
