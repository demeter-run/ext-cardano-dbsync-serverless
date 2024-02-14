use std::str::FromStr;

use deadpool_postgres::{Manager, ManagerConfig, Pool, RecyclingMethod};
use tokio_postgres::{NoTls, Row};

use crate::{get_config, Error};

#[derive(Clone)]
pub struct Postgres {
    pool: Pool,
}

impl Postgres {
    pub async fn try_new(url: &str) -> Result<Self, Error> {
        let mgr_config = ManagerConfig {
            recycling_method: RecyclingMethod::Fast,
        };

        let config = tokio_postgres::Config::from_str(url)?;

        let mgr = Manager::from_config(config, NoTls, mgr_config);
        let pool = Pool::builder(mgr).build()?;

        Ok(Self { pool })
    }

    pub async fn create_user(&self, username: &str, password: &str) -> Result<(), Error> {
        if self.user_exist(username).await? {
            return Ok(());
        }

        let query_create_user = format!("create user \"{username}\" with password '{password}';");
        let query_grant = format!("grant select on all tables in schema public to \"{username}\";");

        let timeout = get_config().query_timeout;
        let query_set_timeout =
            format!("alter role \"{username}\" set statement_timeout = '{timeout}';");

        let mut client = self.pool.get().await?;
        let tx = client.transaction().await?;

        let user_stmt = tx.prepare(&query_create_user).await?;
        let user_result = tx.execute(&user_stmt, &[]).await;
        if let Err(err) = user_result {
            tx.rollback().await?;
            return Err(Error::PgError(err.to_string()));
        }

        let grant_stmt = tx.prepare(&query_grant).await?;
        let grant_result = tx.execute(&grant_stmt, &[]).await;
        if let Err(err) = grant_result {
            tx.rollback().await?;
            return Err(Error::PgError(err.to_string()));
        }

        let set_timeout_stmt = tx.prepare(&query_set_timeout).await?;
        let set_timeout_result = tx.execute(&set_timeout_stmt, &[]).await;
        if let Err(err) = set_timeout_result {
            tx.rollback().await?;
            return Err(Error::PgError(err.to_string()));
        }

        tx.commit().await?;
        Ok(())
    }

    pub async fn drop_user(&self, username: &str) -> Result<(), Error> {
        if !self.user_exist(username).await? {
            return Ok(());
        }

        let query_reassign = format!("reassign owned by \"{username}\" to postgres;");
        let query_revoke = format!("drop owned by \"{username}\";");
        let query_drop_user = format!("drop user \"{username}\";");

        let mut client = self.pool.get().await?;
        let tx = client.transaction().await?;

        let reassign_stmt = tx.prepare(&query_reassign).await?;
        let reassign_result = tx.execute(&reassign_stmt, &[]).await;
        if let Err(err) = reassign_result {
            tx.rollback().await?;
            return Err(Error::PgError(err.to_string()));
        }

        let revoke_stmt = tx.prepare(&query_revoke).await?;
        let revoke_result = tx.execute(&revoke_stmt, &[]).await;
        if let Err(err) = revoke_result {
            tx.rollback().await?;
            return Err(Error::PgError(err.to_string()));
        }

        let drop_user_stmt = tx.prepare(&query_drop_user).await?;
        let drop_user_result = tx.execute(&drop_user_stmt, &[]).await;
        if let Err(err) = drop_user_result {
            tx.rollback().await?;
            return Err(Error::PgError(err.to_string()));
        }

        tx.commit().await?;
        Ok(())
    }

    async fn user_exist(&self, username: &str) -> Result<bool, Error> {
        let query = "select usesysid from pg_user where pg_user.usename = $1;";

        let client = self.pool.get().await?;

        let stmt = client.prepare(query).await?;
        let result = client.query_opt(&stmt, &[&username]).await?;

        Ok(result.is_some())
    }

    pub async fn find_metrics_by_user(
        &self,
        username: &str,
    ) -> Result<Option<UserStatements>, Error> {
        let query_metrics = "select
            usename,
            sum(total_exec_time) as total_exec_time
        from
            pg_stat_statements
        inner join
            pg_catalog.pg_user on pg_catalog.pg_user.usesysid = userid
        where 
            pg_catalog.pg_user.usename = $1
        group by
            usename;";

        let client = self.pool.get().await?;

        let stmt = client.prepare(query_metrics).await?;
        let result = client.query_opt(&stmt, &[&username]).await?;

        Ok(result.as_ref().map(|row| row.into()))
    }
}

#[derive(Debug, Clone)]
pub struct UserStatements {
    pub usename: String,
    pub total_exec_time: f64,
}
impl From<&Row> for UserStatements {
    fn from(row: &Row) -> Self {
        Self {
            usename: row.get("usename"),
            total_exec_time: row.get("total_exec_time"),
        }
    }
}
