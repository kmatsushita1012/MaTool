//
//  Extensions.swift
//  matool-shared
//
//  Created by 松下和也 on 2026/01/09.
//

public extension Array where Element: Identifiable & Equatable & Sendable {

    /// 配列差分を検出して処理、更新後の配列を返す
    /// - Parameters:
    ///   - with: 新しい配列
    ///   - onAdd: 追加されたアイテムを受け取り、新しいアイテムを返す async throws
    ///   - onUpdate: 更新されたアイテムを受け取り、新しいアイテムを返す async throws
    ///   - onDelete: 削除されたアイテムを受け取る async throws
    /// - Returns: 差分反映後の配列
    /// - Throws: SharedError.unknown にまとめて throw
    func diff(
        with new: [Element],
        onAdd: @Sendable @escaping (Element) async throws -> Element,
        onUpdate: @Sendable @escaping (Element) async throws -> Element,
        onDelete: @Sendable @escaping (Element) async throws -> Void
    ) async throws -> [Element] {

        let oldDict = Dictionary(uniqueKeysWithValues: self.map { ($0.id, $0) })
        let newDict = Dictionary(uniqueKeysWithValues: new.map { ($0.id, $0) })
        
        var results = [Result<Element, Error>]()
        
        await withTaskGroup(of: Result<Element, Error>?.self) { group in
            // 追加 or 更新
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
            
            // 削除
            for oldItem in self where newDict[oldItem.id] == nil {
                group.addTask {
                    do { try await onDelete(oldItem) }
                    catch { return .failure(error) }
                    return nil // 削除は結果配列に入れない
                }
            }
            
            // 集約
            for await result in group {
                if let result = result {
                    results.append(result)
                }
            }
        }
        
        // エラー集約
        let errors = results.compactMap { result -> String? in
            if case .failure(let err) = result { return err.localizedDescription }
            return nil
        }
        
        if !errors.isEmpty {
            throw SharedError.unknown(message: errors.joined(separator: "\n"))
        }
        
        // 成功アイテムだけ返す
        return results.compactMap { result in
            if case .success(let item) = result { return item }
            return nil
        }
    }
}
