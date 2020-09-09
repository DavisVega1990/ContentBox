/**
 * This migration is to migrate ContentBox v4 databases to v5 standards.
 */
component {

	variables.today      = now();
	variables.siteTables = [
		"cb_category",
		"cb_content",
		"cb_menu",
		"cb_setting"
	];
	variables.newPermissions = [
		{
			name        : "SITES_ADMIN",
			description : "Ability to manage sites"
		}
	];

	function up( schema, query ){
		transaction {
			try {
				// Update Boolean Bits
				updateBooleanBits( argumentCollection = arguments );
				// Create Default Site
				arguments.siteId = createDefaultSite( argumentCollection = arguments );
				// Create Site Relationships
				createSiteRelationships( argumentCollection = arguments );
				// Create New Permissions
				createPermissions( argumentCollection = arguments );
				// Update Admin role with Site Permission
				updateAdminPermissions( argumentCollection = arguments );
				// Remove unused unique constraints
				removeUniqueConstraints( argumentCollection = arguments );
			} catch ( any e ) {
				transactionRollback();
				systemOutput( e.stacktrace, true );
				rethrow;
			}
		}
	}

	function down( schema, query ){
		// Remove Site Relationships
		variables.siteTables.each( ( thisTable ) => {
			schema.alter( thisTable, ( table ) => {
				table.dropColumn( "FK_siteId" );
			} );
			systemOutput( "√ - Removed site relationship to '#thisTable#'", true );
		} );

		// Remove Site Table
		arguments.schema.drop( "cb_site" );

		// Remove permissions
		arguments.query
			.newQuery()
			.from( "cb_permissions" )
			.where( "name", "SITES_ADMIN" )
			.delete();
	}

	/********************* MIGRATION UPDATES *************************/

	private function removeUniqueConstraints( schema, query ){
		// Remove Setting Name Unique Constraint
		try {
			schema.alter( "cb_setting", ( table ) => table.dropConstraint( "name" ) );
			systemOutput( "√ - Setting name unique constraint dropped", true );
		} catch ( any e ) {
			if ( findNoCase( "column/key exists", e.message ) ) {
				systemOutput(
					"√ - Setting name unique constraint deletion skipped as it doesn't exist",
					true
				);
			} else {
				rethrow;
			}
		}

		// Remove Content Unique Constraint
		try {
			schema.alter( "cb_content", ( table ) => table.dropConstraint( "slug" ) );
			systemOutput( "√ - Content slug unique constraint dropped", true );
		} catch ( any e ) {
			if ( findNoCase( "column/key exists", e.message ) ) {
				systemOutput(
					"√ - Content slug unique constraint deletion skipped as it doesn't exist",
					true
				);
			} else {
				rethrow;
			}
		}

		// Remove category unique constraint
		try {
			schema.alter( "cb_category", ( table ) => table.dropConstraint( "slug" ) );
			systemOutput( "√ - Content Category slug unique constraint dropped", true );
		} catch ( any e ) {
			if ( findNoCase( "column/key exists", e.message ) ) {
				systemOutput(
					"√ - Content Category slug unique constraint deletion skipped as it doesn't exist",
					true
				);
			} else {
				rethrow;
			}
		}

		// Remove menu unique constraint
		try {
			schema.alter( "cb_menu", ( table ) => table.dropConstraint( "slug" ) );
			systemOutput( "√ - Menu slug unique constraint dropped", true );
		} catch ( any e ) {
			if ( findNoCase( "column/key exists", e.message ) ) {
				systemOutput(
					"√ - Menu slug unique constraint deletion skipped as it doesn't exist",
					true
				);
			} else {
				rethrow;
			}
		}
	}

	private function createSiteRelationships( schema, query, siteId ){
		variables.siteTables.each( ( thisTable ) => {
			// Check for columns created
			cfdbinfo(
				name  = "local.qColumns",
				type  = "columns",
				table = thisTable
			);

			var isSiteColumnCreated = qColumns.filter( ( thisRow ) => {
				// systemOutput( thisRow, true );
				return thisRow.column_name == "FK_siteId"
			} ).recordCount > 0;

			if ( isSiteColumnCreated ) {
				systemOutput(
					"√ - Site relationship for '#thisTable#' already defined, skipping",
					true
				);
			} else {
				// Add site id relationship
				schema.alter( thisTable, ( table ) => {
					table.addColumn( table.unsignedInteger( "FK_siteId" ) );
				} );
				systemOutput( "√ - Created site column on '#thisTable#'", true );
			}

			// Seed with site id
			query
				.newQuery()
				.from( thisTable )
				.whereNull( "FK_siteId" )
				.orWhere( "FK_siteId", 0 )
				.update( { "FK_siteId" : siteId } );

			systemOutput( "√ - Populated '#thisTable#' with default site data", true );

			// Add foreign key
			if ( !isSiteColumnCreated ) {
				schema.alter( thisTable, ( table ) => {
					table.addConstraint(
						table
							.foreignKey( "FK_siteId" )
							.references( "siteId" )
							.onTable( "cb_site" )
							.onDelete( "CASCADE" )
					);
				} );
				systemOutput( "√ - Created site foreign key on '#thisTable#'", true );
			}
		} );
	}

	/**
	 * Updates all the boolean bits to tinyInteger to support cross-db compatibilities and better boolean support
	 */
	private function updateBooleanBits( schema, query ){
		arguments.schema.alter( "cb_author", ( table ) => {
			table.modifyColumn( "isDeleted", table.tinyInteger( "isDeleted" ).default( 0 ) );
			table.modifyColumn( "isActive", table.tinyInteger( "isActive" ).default( 1 ) );
		} );
		systemOutput( "√ - Author boolean bits updated", true );

		arguments.schema.alter( "cb_category", ( table ) => {
			table.modifyColumn( "isDeleted", table.tinyInteger( "isDeleted" ).default( 0 ) );
		} );
		systemOutput( "√ - Category boolean bits updated", true );

		arguments.schema.alter( "cb_comment", ( table ) => {
			table.modifyColumn( "isDeleted", table.tinyInteger( "isDeleted" ).default( 0 ) );
			table.modifyColumn( "isApproved", table.tinyInteger( "isApproved" ).default( 0 ) );
		} );
		systemOutput( "√ - Comment boolean bits updated", true );

		arguments.schema.alter( "cb_content", ( table ) => {
			table.modifyColumn( "isDeleted", table.tinyInteger( "isDeleted" ).default( 0 ) );
			table.modifyColumn( "isPublished", table.tinyInteger( "isPublished" ).default( 1 ) );
			table.modifyColumn( "allowComments", table.tinyInteger( "allowComments" ).default( 1 ) );
			table.modifyColumn( "cache", table.tinyInteger( "cache" ).default( 1 ) );
			table.modifyColumn( "cacheLayout", table.tinyInteger( "cacheLayout" ).default( 1 ) );
			table.modifyColumn( "showInSearch", table.tinyInteger( "showInSearch" ).default( 1 ) );
		} );
		systemOutput( "√ - Content boolean bits updated", true );

		arguments.schema.alter( "cb_contentVersion", ( table ) => {
			table.modifyColumn( "isDeleted", table.tinyInteger( "isDeleted" ).default( 0 ) );
			table.modifyColumn( "isActive", table.tinyInteger( "isActive" ).default( 1 ) );
		} );
		systemOutput( "√ - Content Versioning boolean bits updated", true );

		arguments.schema.alter( "cb_customField", ( table ) => {
			table.modifyColumn( "isDeleted", table.tinyInteger( "isDeleted" ).default( 0 ) );
		} );
		systemOutput( "√ - Custom Fields boolean bits updated", true );

		arguments.schema.alter( "cb_loginAttempts", ( table ) => {
			table.modifyColumn( "isDeleted", table.tinyInteger( "isDeleted" ).default( 0 ) );
		} );
		systemOutput( "√ - Audit log boolean bits updated", true );

		arguments.schema.alter( "cb_menu", ( table ) => {
			table.modifyColumn( "isDeleted", table.tinyInteger( "isDeleted" ).default( 0 ) );
		} );
		systemOutput( "√ - Menus boolean bits updated", true );

		arguments.schema.alter( "cb_menuItem", ( table ) => {
			table.modifyColumn( "isDeleted", table.tinyInteger( "isDeleted" ).default( 0 ) );
		} );
		systemOutput( "√ - Menu Items boolean bits updated", true );

		arguments.schema.alter( "cb_module", ( table ) => {
			table.modifyColumn( "isDeleted", table.tinyInteger( "isDeleted" ).default( 0 ) );
			table.modifyColumn( "isActive", table.tinyInteger( "isActive" ).default( 0 ) );
		} );
		systemOutput( "√ - Modules boolean bits updated", true );

		arguments.schema.alter( "cb_page", ( table ) => {
			table.modifyColumn( "showInMenu", table.tinyInteger( "showInMenu" ).default( 1 ) );
			table.modifyColumn( "SSLOnly", table.tinyInteger( "SSLOnly" ).default( 0 ) );
		} );
		systemOutput( "√ - Pages boolean bits updated", true );

		arguments.schema.alter( "cb_permission", ( table ) => {
			table.modifyColumn( "isDeleted", table.tinyInteger( "isDeleted" ).default( 0 ) );
		} );
		systemOutput( "√ - Permissions boolean bits updated", true );

		arguments.schema.alter( "cb_permissionGroup", ( table ) => {
			table.modifyColumn( "isDeleted", table.tinyInteger( "isDeleted" ).default( 0 ) );
		} );
		systemOutput( "√ - Permission Groups boolean bits updated", true );

		arguments.schema.alter( "cb_role", ( table ) => {
			table.modifyColumn( "isDeleted", table.tinyInteger( "isDeleted" ).default( 0 ) );
		} );
		systemOutput( "√ - Roles boolean bits updated", true );

		arguments.schema.alter( "cb_securityRule", ( table ) => {
			table.modifyColumn( "isDeleted", table.tinyInteger( "isDeleted" ).default( 0 ) );
			table.modifyColumn( "useSSL", table.tinyInteger( "useSSL" ).default( 0 ) );
		} );
		systemOutput( "√ - Security Rules boolean bits updated", true );

		arguments.schema.alter( "cb_setting", ( table ) => {
			table.modifyColumn( "isDeleted", table.tinyInteger( "isDeleted" ).default( 0 ) );
			table.modifyColumn( "isCore", table.tinyInteger( "isCore" ).default( 0 ) );
		} );
		systemOutput( "√ - Settings boolean bits updated", true );

		arguments.schema.alter( "cb_stats", ( table ) => {
			table.modifyColumn( "isDeleted", table.tinyInteger( "isDeleted" ).default( 0 ) );
		} );
		systemOutput( "√ - Stats boolean bits updated", true );

		arguments.schema.alter( "cb_subscribers", ( table ) => {
			table.modifyColumn( "isDeleted", table.tinyInteger( "isDeleted" ).default( 0 ) );
		} );
		systemOutput( "√ - Subscribers boolean bits updated", true );

		arguments.schema.alter( "cb_subscriptions", ( table ) => {
			table.modifyColumn( "isDeleted", table.tinyInteger( "isDeleted" ).default( 0 ) );
		} );
		systemOutput( "√ - Subscriptions boolean bits updated", true );

		systemOutput( "********************************************", true );
		systemOutput( "√√√ All boolean bit updates finalized", true );
		systemOutput( "********************************************", true );
	}

	/**
	 * Updates the admin with newer permissions
	 */
	private function updateAdminPermissions( schema, query ){
		var admin = arguments.query
			.newQuery()
			.select( "roleID" )
			.from( "cb_role" )
			.where( "role", "Administrator" )
			.first();

		var siteAdmin = arguments.query
			.newQuery()
			.select( "permissionID" )
			.from( "cb_permission" )
			.where( "permission", "SITES_ADMIN" )
			.first();

		var sitePermissionFound = !arguments.query
			.newQuery()
			.select( "FK_permissionID" )
			.from( "cb_rolePermissions" )
			.where( "FK_permissionID", siteAdmin.permissionId )
			.first()
			.isEmpty();

		if ( !sitePermissionFound ) {
			arguments.query
				.newQuery()
				.from( "cb_rolePermissions" )
				.insert( {
					"FK_roleID"       : admin.roleID,
					"FK_permissionID" : siteAdmin.permissionID
				} );
			systemOutput( "√ - Admin role updated with new permissions", true );
		} else {
			systemOutput( "√ - Admin role already has the new permissions, skipping", true );
		}
	}

	/**
	 * Creates the new permissions
	 */
	private function createPermissions( schema, query ){
		variables.newPermissions.each( ( thisPermission ) => {
			var isNewPermission = query
				.newQuery()
				.select( "permissionID" )
				.from( "cb_permission" )
				.where( "permission", thisPermission.name )
				.first()
				.isEmpty();

			if ( !isNewPermission ) {
				systemOutput(
					"√ - #thisPermission.name# permission already in database skipping",
					true
				);
				return;
			}

			query
				.newQuery()
				.from( "cb_permission" )
				.insert( {
					"createdDate"  : today,
					"modifiedDate" : today,
					"isDeleted"    : 0,
					"permission"   : thisPermission.name,
					"description"  : thisPermission.description
				} );
			systemOutput( "√ - #thisPermission.name# permission created", true );
		} );
	}

	/**
	 * Create multi-site support
	 */
	private function createDefaultSite( schema, query ){
		cfdbinfo( name = "local.qTables", type = "tables" );

		var isSiteTableCreated = qTables.filter( ( thisRow ) => {
			// systemOutput( thisRow, true );
			return thisRow.table_name == "cb_site"
		} ).recordCount > 0;

		if ( !isSiteTableCreated ) {
			// Create the site table
			arguments.schema.create( "cb_site", ( table ) => {
				table.increments( "siteId" );
				table.dateTime( "createdDate" );
				table.dateTime( "modifiedDate" );
				table.tinyInteger( "isDeleted" ).default( 0 );
				table.string( "name" );
				table.string( "slug" ).unique();
				table.longText( "description" ).nullable();
				table.string( "domainRegex" ).nullable();
				table.string( "keywords" ).nullable();
				table.string( "tagline" ).nullable();
				table.string( "homepage" ).nullable();
				table.tinyInteger( "isBlogEnabled" ).default( 1 );
				table.tinyInteger( "isSitemapEnabled" ).default( 1 );
				table.tinyInteger( "poweredByHeader" ).default( 1 );
				table.tinyInteger( "adminBar" ).default( 1 );
				table.tinyInteger( "isSSL" ).default( 0 );
				table.string( "activeTheme" ).nullable();
				table.longText( "notificationEmails" ).nullable();
				table.tinyInteger( "notifyOnEntries" ).default( 1 );
				table.tinyInteger( "notifyOnPages" ).default( 1 );
				table.tinyInteger( "notifyOnContentStore" ).default( 1 );
				table.string( "domain" ).nullable();
			} );
			systemOutput( "√ - Site table created", true );
		} else {
			systemOutput( "√ - Site table already created, skipping", true );
		}

		var defaultSiteRecord = query
			.newQuery()
			.select( "siteId" )
			.from( "cb_site" )
			.where( "slug", "default" )
			.first();

		if ( defaultSiteRecord.isEmpty() ) {
			var qResults = arguments.query
				.newQuery()
				.from( "cb_site" )
				.insert( {
					"siteId"           : 1,
					"createdDate"      : today,
					"modifiedDate"     : today,
					"isDeleted"        : 0,
					"name"             : "Default Site",
					"slug"             : "default",
					"description"      : "The default site",
					"domainRegex"      : ".*",
					"isBlogEnabled"    : 1,
					"isSitemapEnabled" : 1,
					"poweredByHeader"  : 1,
					"adminBar"         : 1,
					"isSSL"            : 0,
					"activeTheme"      : "default",
					"domain"           : "127.0.0.1"
				} );
			systemOutput( "√ - Default site created", true );
			return qResults.result.generatedKey;
		} else {
			systemOutput( "√ - Default site already created, skipping", true );
			return defaultSiteRecord.siteId;
		}
	}

}
