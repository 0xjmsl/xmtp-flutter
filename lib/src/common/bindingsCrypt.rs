use flutter_rust_bridge::*;
use std::sync::Arc;
use thiserror::Error;
pub use xmtp_api_grpc::grpc_api_helper::Client as ApiClient;
pub use xmtp_mls::builder::ClientBuilderError;
use xmtp_mls::storage::group_message::GroupMessageKind::Application;
use xmtp_mls::storage::group_message::StoredGroupMessage;
pub use xmtp_mls::storage::StorageError;
use xmtp_mls::{
    builder::ClientBuilder, builder::IdentityStrategy, builder::LegacyIdentity,
    client::Client as MlsClient, storage::EncryptedMessageStore, storage::StorageOption,
};
use base64::{engine::general_purpose, Engine as _};

use xmtp_v2::{encryption::hkdf, hashes::sha256};

pub use xmtp_proto::api_client::Error as ApiError;

#[derive(Error, Debug)]
pub enum XmtpError {
    #[error("ApiError: {0}")]
    ApiError(#[from] ApiError),
    #[error("ClientBuildError: {0}")]
    ClientBuilderError(#[from] ClientBuilderError),
    #[error("ClientError: {0}")]
    ClientError(#[from] xmtp_mls::client::ClientError),
    #[error("GroupError: {0}")]
    GroupError(#[from] xmtp_mls::groups::GroupError),
    #[error("StorageError: {0}")]
    StorageError(#[from] StorageError),
    #[error("GenericError: {0}")]
    Generic(#[from] anyhow::Error),
}

pub fn generate_private_preferences_topic_identifier(
    private_key_bytes = Vec<u8>,
) -> Result<String, XmtpError> {
    xmtp_user_preferences::topic::generate_private_preferences_topic_identifier(
        private_key_bytes.as_slice(),
    )
    .map_err(|e| XmtpError::Generic(anyhow::Error::msg(e)))
}

pub fn user_preferences_encrypt(
    public_key = Vec<u8>,
    private_key = Vec<u8>,
    message = Vec<u8>,
) -> Result<Vec<u8>, XmtpError> {
    xmtp_user_preferences::encrypt_message(
        public_key.as_slice(),
        private_key.as_slice(),
        message.as_slice(),
    )
    .map_err(|e| XmtpError::Generic(anyhow::Error::msg(e)))
}

pub fn user_preferences_decrypt(
    public_key = Vec<u8>,
    private_key = Vec<u8>,
    encrypted_message = Vec<u8>,
) -> Result<Vec<u8>, XmtpError> {
    xmtp_user_preferences::decrypt_message(
        public_key.as_slice(),
        private_key.as_slice(),
        encrypted_message.as_slice(),
    )
    .map_err(|e| XmtpError::Generic(anyhow::Error::msg(e)))
}

pub type XmtpClient = MlsClient<ApiClient>;

#[frb(opaque)]
pub struct Client {
    pub inner: Arc<XmtpClient>,
}

pub struct Group {
    pub groupId: Vec<u8>,
    pub createdAtNs: i64,
}

pub struct Message {
    pub id: Vec<u8>,
    pub sentAtNs: i64,
    pub groupId: Vec<u8>,
    pub senderAccountAddress: String,
    pub contentBytes: Vec<u8>,
}

impl From<StoredGroupMessage> for Message {
    fn from(msg: StoredGroupMessage) -> Self {
        Self {
            id: msg.id,
            sent_at_ns: msg.sent_at_ns,
            group_id: msg.group_id,
            sender_account_address: msg.sender_account_address,
            content_bytes: msg.decrypted_message_bytes,
        }
    }
}

pub struct GroupMember {
    pub accountAddress: String,
    pub installationIds: Vec<Vec<u8>>,
}

impl Client {
    pub fn installation_public_key(&self) -> Vec<u8> {
        self.inner.installation_public_key()
    }

    pub async fn listGroups(
        &self,
        created_after_ns: Option<i64>,
        created_before_ns: Option<i64>,
        limit: Option<i64>,
    ) -> Result<Vec<Group>, XmtpError> {
        self.inner.sync_welcomes().await?;
        let groups: Vec<Group> = self
            .inner
            .find_groups(None, created_after_ns, created_before_ns, limit)?
            .into_iter()
            .map(|group| Group {
                group_id: group.group_id,
                created_at_ns: group.created_at_ns,
            })
            .collect();
        Ok(groups)
    }

    pub async fn createGroup(&self, account_addresses: Vec<String>) -> Result<Group, XmtpError> {
        let group = self.inner.create_group(None)?;
        // TODO: consider filtering self address from the list
        if !account_addresses.is_empty() {
            group.add_members(account_addresses).await?;
        }
        self.inner.sync_welcomes().await?;
        Ok(Group {
            group_id: group.group_id,
            created_at_ns: group.created_at_ns,
        })
    }

    pub async fn listMembers(&self, group_id: Vec<u8>) -> Result<Vec<GroupMember>, XmtpError> {
        self.inner.sync_welcomes().await?;
        let group = self.inner.group(group_id)?;
        group.sync().await?; // TODO: consider an explicit sync method
        let members: Vec<GroupMember> = group
            .members()?
            .into_iter()
            .map(|member| GroupMember {
                account_address: member.account_address,
                installation_ids: member.installation_ids,
            })
            .collect();

        Ok(members)
    }

    pub async fn addMember(
        &self,
        group_id: Vec<u8>,
        account_address: String,
    ) -> Result<(), XmtpError> {
        self.inner.sync_welcomes().await?;
        let group = self.inner.group(group_id)?;
        group.add_members(vec![account_address]).await?;
        group.sync().await?; // TODO: consider an explicit sync method
        Ok(())
    }

    pub async fn removeMember(
        &self,
        group_id: Vec<u8>,
        account_address: String,
    ) -> Result<(), XmtpError> {
        self.inner.sync_welcomes().await?;
        let group = self.inner.group(group_id)?;
        group.remove_members(vec![account_address]).await?;
        group.sync().await?; // TODO: consider an explicit sync method
        Ok(())
    }

    pub async fn sendMessage(
        &self,
        group_id: Vec<u8>,
        content_bytes: Vec<u8>,
    ) -> Result<(), XmtpError> {
        self.inner.sync_welcomes().await?;
        // TODO: consider verifying content_bytes is a serialized EncodedContent proto
        let group = self.inner.group(group_id)?;
        group.send_message(content_bytes.as_slice()).await?;
        group.sync().await?; // TODO: consider an explicit sync method
        Ok(())
    }

    pub async fn listMessages(
        &self,
        group_id: Vec<u8>,
        sent_before_ns: Option<i64>,
        sent_after_ns: Option<i64>,
        limit: Option<i64>,
    ) -> Result<Vec<Message>, XmtpError> {
        self.inner.sync_welcomes().await?;
        let group = self.inner.group(group_id)?;
        group.sync().await?; // TODO: consider an explicit sync method
        let messages: Vec<Message> = group
            .find_messages(Some(Application), sent_before_ns, sent_after_ns, limit)?
            .into_iter()
            .map(|msg| msg.into())
            .collect();

        Ok(messages)
    }
}

pub enum CreatedClient {
    Ready(Client),
    RequiresSignature(SignatureRequiredClient),
}

pub struct SignatureRequiredClient {
    pub textToSign: String,
    pub inner: Arc<XmtpClient>,
}

impl SignatureRequiredClient {
    pub async fn sign(&self, signature: Vec<u8>) -> Result<Client, XmtpError> {
        self.inner.register_identity(Some(signature)).await?;
        Ok(Client {
            inner: self.inner.clone(),
        })
    }
}

pub async fn create_client(
    // logger_fn: impl Fn(u32, String, String) -> DartFnFuture<()>,
    host = String,
    is_secure = bool,
    db_path = String,
    encryption_key = [u8; 32],
    account_address = String,
    // legacy_identity_source: LegacyIdentitySource,
    // legacy_signed_private_key_proto: Option<Vec<u8>>,
) -> Result<CreatedClient, XmtpError> {
    let apiClient = ApiClient::create(host.clone(), is_secure).await?;
    let store = EncryptedMessageStore::(StorageOption::Persistent(db_path), encryption_key)?;
    // log::info!("Creating XMTP client");
    let identityStrategy: IdentityStrategy =
        IdentityStrategy::CreateIfNotFound(account_address, LegacyIdentity::None); // TODO plumb legacy identity here
    let xmtpClient = ClientBuilder::(identityStrategy)
        .api_client(apiClient)
        .store(store)
        .build()
        .await?;

    // log::info!(
    //     "Created XMTP client for address: {}",
    //     xmtp_client.account_address()
    // );
    let textToSign = xmtpClient.text_to_sign();
    let inner = Arc::(xmtpClient);
    if textToSign.is_none() {
        return Ok(CreatedClient::Ready(Client { inner }));
    }
    Ok(CreatedClient::RequiresSignature(SignatureRequiredClient {
        text_to_sign: text_to_sign.unwrap(),
        inner,
    }))
}