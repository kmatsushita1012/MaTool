//
//  RemoteRepository.swift
//  FesTracking2
//
//  Created by 松下和也 on 2025/03/02.
//

import Foundation
@DependencyClient
public struct RemoteClient: Sendable {
    public var searchRepos: @Sendable (_ query: String, _ page: Int) async throws -> SearchReposResponse
    public var getRepoDetail: @Sendable (_ owner: String, _ repo: String) async throws -> RepoDetailResponse
}
