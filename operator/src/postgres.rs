use tokio_postgres::{Client, NoTls, Row};

use crate::Error;

pub struct Postgres {
    client: Client,
}

impl Postgres {
    pub async fn new(url: &str) -> Result<Self, Error> {
        let (client, connection) = tokio_postgres::connect(url, NoTls).await?;

        tokio::spawn(async move {
            if let Err(e) = connection.await {
                eprintln!("connection error: {}", e);
            }
        });

        Ok(Self { client })
    }

    pub async fn create_user(&mut self, username: &str, password: &str) -> Result<(), Error> {
        let query_create_user = format!("create user \"{username}\" with password '{password}';");
        let query_grant = format!("grant select on all tables in schema public to \"{username}\";");

        let tx = self.client.transaction().await?;

        let user_stmt = tx.prepare(&query_create_user).await?;
        let user_result = tx.execute(&user_stmt, &[]).await;
        if let Err(err) = user_result {
            tx.rollback().await?;
            return Err(Error::PgError(err));
        }

        let grant_stmt = tx.prepare(&query_grant).await?;
        let grant_result = tx.execute(&grant_stmt, &[]).await;
        if let Err(err) = grant_result {
            tx.rollback().await?;
            return Err(Error::PgError(err));
        }

        tx.commit().await?;
        Ok(())
    }

    pub async fn drop_user(&mut self, username: &str) -> Result<(), Error> {
        let query_reassign = format!("reassign owned by {username} to postgres;");
        let query_revoke = format!("drop owned by {username};");
        let query_drop_user = format!("drop user {username};");

        let tx = self.client.transaction().await?;

        let reassign_stmt = tx.prepare(&query_reassign).await?;
        let reassign_result = tx.execute(&reassign_stmt, &[]).await;
        if let Err(err) = reassign_result {
            tx.rollback().await?;
            return Err(Error::PgError(err));
        }

        let revoke_stmt = tx.prepare(&query_revoke).await?;
        let revoke_result = tx.execute(&revoke_stmt, &[]).await;
        if let Err(err) = revoke_result {
            tx.rollback().await?;
            return Err(Error::PgError(err));
        }

        let drop_user_stmt = tx.prepare(&query_drop_user).await?;
        let drop_user_result = tx.execute(&drop_user_stmt, &[]).await;
        if let Err(err) = drop_user_result {
            tx.rollback().await?;
            return Err(Error::PgError(err));
        }

        tx.commit().await?;
        Ok(())
    }

    pub async fn user_metrics(&self) -> Result<Option<Vec<UserStatements>>, Error> {
        let query_metrics = "SELECT
            usename,
            SUM(total_exec_time) AS total_exec_time
        FROM
            pg_stat_statements
        inner join
            pg_catalog.pg_user on pg_catalog.pg_user.usesysid = userid
        where 
            pg_catalog.pg_user.usename like '%.prj-%'
        group by
            usename;";

        let stmt = self.client.prepare(query_metrics).await?;
        let result = self.client.query(&stmt, &[]).await?;

        if !result.is_empty() {
            let user_statements: Vec<UserStatements> =
                result.iter().map(|row| row.into()).collect();
            return Ok(Some(user_statements));
        }

        Ok(None)
    }
}

#[derive(Debug)]
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
