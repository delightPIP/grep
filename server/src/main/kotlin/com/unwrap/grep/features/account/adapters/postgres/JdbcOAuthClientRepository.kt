package com.unwrap.grep.features.account.adapters.postgres

import com.unwrap.grep.features.account.domain.OAuthClient
import com.unwrap.grep.features.account.domain.OAuthClientRepository
import org.springframework.jdbc.core.simple.JdbcClient
import org.springframework.stereotype.Repository

/** oauth_clients(V4). */
@Repository
class JdbcOAuthClientRepository(private val jdbc: JdbcClient) : OAuthClientRepository {

	override fun insert(client: OAuthClient) {
		jdbc.sql("INSERT INTO oauth_clients (id, name, redirect_uris) VALUES (:id, :name, :uris)")
			.param("id", client.id)
			.param("name", client.name)
			.param("uris", client.redirectUris.toTypedArray())
			.update()
	}

	override fun find(id: String): OAuthClient? =
		jdbc.sql("SELECT id, name, redirect_uris FROM oauth_clients WHERE id = :id")
			.param("id", id)
			.query { rs, _ ->
				@Suppress("UNCHECKED_CAST")
				OAuthClient(rs.getString("id"), rs.getString("name"), (rs.getArray("redirect_uris").array as Array<String>).toList())
			}
			.optional()
			.orElse(null)
}
