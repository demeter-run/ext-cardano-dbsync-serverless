use tokio_postgres::{Client, NoTls};

use crate::Error;

pub async fn connect(url: &str) -> Result<Client, Error> {
    let (client, connection) = tokio_postgres::connect(url, NoTls).await?;

    tokio::spawn(async move {
        if let Err(e) = connection.await {
            eprintln!("connection error: {}", e);
        }
    });

    Ok(client)
}

pub async fn user_create(client: &mut Client, username: &str, password: &str) -> Result<(), Error> {
    let query_create_user = format!("create user \"{username}\" with password '{password}';");
    let query_create_role =
        format!("grant select on all tables in schema public to \"{username}\";");

    let tx = client.transaction().await?;

    let user_stmt = tx.prepare(&query_create_user).await?;
    let user_result = tx.execute(&user_stmt, &[]).await;
    if let Err(err) = user_result {
        tx.rollback().await?;
        return Err(Error::PgError(err));
    }

    let role_stmt = tx.prepare(&query_create_role).await?;
    let role_result = tx.execute(&role_stmt, &[]).await;
    if let Err(err) = role_result {
        tx.rollback().await?;
        return Err(Error::PgError(err));
    }

    tx.commit().await?;
    Ok(())
}

pub async fn user_disable(client: &mut Client, username: &str) -> Result<(), Error> {
    let query_revoke_login = format!("alter user \"{username}\" with nologin;");

    let revoke_stmt = client.prepare(&query_revoke_login).await?;
    client.execute(&revoke_stmt, &[]).await?;

    Ok(())
}

pub async fn user_enable(client: &mut Client, username: &str, password: &str) -> Result<(), Error> {
    let query_grant_login = format!("alter user \"{username}\" with login;");
    let query_alter_password = format!("alter user \"{username}\" with password '{password}';");

    let tx = client.transaction().await?;

    let login_stmt = tx.prepare(&query_grant_login).await?;
    let login_result = tx.execute(&login_stmt, &[]).await;
    if let Err(err) = login_result {
        tx.rollback().await?;
        return Err(Error::PgError(err));
    }

    let alter_stmt = tx.prepare(&query_alter_password).await?;
    let alter_result = tx.execute(&alter_stmt, &[]).await;
    if let Err(err) = alter_result {
        tx.rollback().await?;
        return Err(Error::PgError(err));
    }

    tx.commit().await?;
    Ok(())
}

pub async fn user_already_exists(client: &mut Client, username: &str) -> Result<bool, Error> {
    let query = "select rolname from pg_roles where rolname = $1;";

    let user_stmt = client.prepare(query).await?;
    let result = client.query_opt(&user_stmt, &[&username]).await?;

    Ok(result.is_some())
}
