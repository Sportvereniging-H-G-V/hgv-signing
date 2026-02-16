# frozen_string_literal: true

class Ability
  include CanCan::Ability

  def initialize(user)
    if user.role == User::ADMIN_ROLE
      # Admin heeft volledige rechten
      can %i[read create update], Template, Abilities::TemplateConditions.collection(user) do |template|
        Abilities::TemplateConditions.entity(template, user:, ability: 'manage')
      end

      can :destroy, Template, account_id: user.account_id
      can :manage, TemplateFolder, account_id: user.account_id
      can :manage, TemplateSharing, template: { account_id: user.account_id }
      can :manage, Submission, account_id: user.account_id
      can :manage, Submitter, account_id: user.account_id
      can :manage, User, account_id: user.account_id
      can :manage, EncryptedConfig, account_id: user.account_id
      can :manage, EncryptedUserConfig, user_id: user.id
      can :manage, AccountConfig, account_id: user.account_id
      can :manage, UserConfig, user_id: user.id
      can :manage, Account, id: user.account_id
      can :manage, :database_export
      can :manage, :database_import
    else
      # Editor: alleen templates lezen en versturen
      # Templates lezen (maar niet bewerken/verwijderen)
      can :read, Template, Abilities::TemplateConditions.collection(user) do |template|
        Abilities::TemplateConditions.entity(template, user:, ability: 'read')
      end

      # Folders lezen (zodat editor mappen kan zien op dashboard)
      can :read, TemplateFolder, account_id: user.account_id

      # Submissions aanmaken (om templates te versturen)
      can :create, Submission, template: { account_id: user.account_id }
      can :new, Submission

      # Eigen profiel beheren (maar geen account settings)
      can :manage, EncryptedUserConfig, user_id: user.id
      can :manage, UserConfig, user_id: user.id
      can :manage, User, id: user.id
    end
  end
end
