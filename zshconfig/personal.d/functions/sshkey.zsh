# Copy SSH public key to remote host
function sshkey {
  ssh-copy-id -i ~/.ssh/id_ed25519.pub "$@"
}
