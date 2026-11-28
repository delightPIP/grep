package com.unwrap.grep.features.archive.config

import com.unwrap.grep.features.archive.api.Embedder
import com.unwrap.grep.features.archive.api.ItemSaveListener
import com.unwrap.grep.features.archive.bundle.domain.AutoGroupRepository
import com.unwrap.grep.features.archive.bundle.domain.AutoGroupService
import com.unwrap.grep.features.archive.transfer.domain.BookmarkImportService
import com.unwrap.grep.features.archive.search.domain.BrowseItemsService
import com.unwrap.grep.features.archive.bundle.domain.BundleRepository
import com.unwrap.grep.features.archive.bundle.domain.BundleService
import com.unwrap.grep.features.archive.transfer.domain.ConnectionReadingService
import com.unwrap.grep.features.archive.transfer.domain.HandoffService
import com.unwrap.grep.features.archive.transfer.domain.HandoffSourceRepository
import com.unwrap.grep.features.archive.transfer.domain.ImportRepository
import com.unwrap.grep.features.archive.transfer.domain.ImportRunner
import com.unwrap.grep.features.archive.item.domain.ItemDetailRepository
import com.unwrap.grep.features.archive.item.domain.ItemDetailService
import com.unwrap.grep.features.archive.item.domain.ItemRepository
import com.unwrap.grep.features.archive.item.domain.ItemRevisionRepository
import com.unwrap.grep.features.archive.search.domain.ItemSearch
import com.unwrap.grep.features.archive.search.domain.NearestItems
import com.unwrap.grep.features.archive.item.domain.ObjectStorage
import com.unwrap.grep.features.archive.search.domain.RelatedSearch
import com.unwrap.grep.features.archive.item.domain.ReviseItemService
import com.unwrap.grep.features.archive.item.domain.SaveItemService
import com.unwrap.grep.features.archive.search.domain.SavedSearchRepository
import com.unwrap.grep.features.archive.search.domain.SavedSearchService
import com.unwrap.grep.features.archive.trash.domain.TrashRepository
import com.unwrap.grep.features.archive.trash.domain.TrashService
import com.unwrap.grep.features.archive.item.domain.UploadRepository
import com.unwrap.grep.features.archive.item.domain.UploadService
import org.springframework.beans.factory.annotation.Value
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import org.springframework.transaction.support.TransactionTemplate
import java.time.Clock

/** archive 도메인 서비스 빈. 도메인 클래스는 Spring을 모른다. */
@Configuration(proxyBeanMethods = false)
class ArchiveConfig {

	@Bean
	fun saveItemService(
		items: ItemRepository,
		uploads: UploadRepository,
		storage: ObjectStorage,
		transaction: TransactionTemplate,
		clock: Clock,
		saveListener: ItemSaveListener,
	) = SaveItemService(items, uploads, storage, transaction, clock, saveListener)

	@Bean
	fun uploadService(uploads: UploadRepository, storage: ObjectStorage, clock: Clock) = UploadService(uploads, storage, clock)

	@Bean
	fun browseItemsService(items: ItemRepository, itemSearch: ItemSearch, relatedSearch: RelatedSearch) =
		BrowseItemsService(items, itemSearch, relatedSearch)

	@Bean
	fun relatedSearch(
		embedder: Embedder,
		nearest: NearestItems,
		@Value("\${grep.semantic.max-distance}") maxDistance: Double,
	) = RelatedSearch(embedder, nearest, maxDistance)

	@Bean
	fun itemDetailService(details: ItemDetailRepository, items: ItemRepository, storage: ObjectStorage) =
		ItemDetailService(details, items, storage)

	@Bean
	fun reviseItemService(revisions: ItemRevisionRepository) = ReviseItemService(revisions)

	@Bean
	fun savedSearchService(searches: SavedSearchRepository, itemSearch: ItemSearch) = SavedSearchService(searches, itemSearch)

	@Bean
	fun trashService(trash: TrashRepository, storage: ObjectStorage, transaction: TransactionTemplate, clock: Clock) =
		TrashService(trash, storage, transaction, clock)

	@Bean
	fun bundleService(bundles: BundleRepository, items: ItemRepository, transaction: TransactionTemplate) =
		BundleService(bundles, items, transaction)

	@Bean
	fun autoGroupService(groups: AutoGroupRepository, clock: Clock) = AutoGroupService(groups, clock)

	@Bean
	fun handoffService(sources: HandoffSourceRepository, bundles: BundleRepository, items: ItemRepository, clock: Clock) =
		HandoffService(sources, bundles, items, clock)

	@Bean
	fun connectionReadingService(
		itemSearch: ItemSearch,
		sources: HandoffSourceRepository,
		details: ItemDetailRepository,
		items: ItemRepository,
		clock: Clock,
	) = ConnectionReadingService(itemSearch, sources, details, items, clock)

	@Bean
	fun bookmarkImportService(
		imports: ImportRepository,
		items: ItemRepository,
		transaction: TransactionTemplate,
		runner: ImportRunner,
	) = BookmarkImportService(imports, items, transaction, runner)
}
