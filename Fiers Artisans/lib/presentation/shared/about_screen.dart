import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import 'profile_ui.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sections = [
      (
        title: 'about.presentation_title'.tr(),
        body: 'about.presentation_body'.tr(),
        icon: Icons.waving_hand_outlined,
      ),
      (
        title: 'about.confidentiality_title'.tr(),
        body: 'about.confidentiality_body'.tr(),
        icon: Icons.privacy_tip_outlined,
      ),
      (
        title: 'about.terms_title'.tr(),
        body: 'about.terms_body'.tr(),
        icon: Icons.rule_folder_outlined,
      ),
      (
        title: 'about.payment_title'.tr(),
        body: 'about.payment_body'.tr(),
        icon: Icons.account_balance_wallet_outlined,
      ),
      (
        title: 'about.legal_title'.tr(),
        body: 'about.legal_body'.tr(),
        icon: Icons.gavel_outlined,
      ),
      (
        title: 'about.data_policy_title'.tr(),
        body: 'about.data_policy_body'.tr(),
        icon: Icons.storage_outlined,
      ),
      (
        title: 'about.licenses_title'.tr(),
        body: 'about.licenses_body'.tr(),
        icon: Icons.description_outlined,
      ),
      (
        title: 'about.version_title'.tr(),
        body: 'about.version_body'.tr(
          namedArgs: {'version': AppConfig.appVersion},
        ),
        icon: Icons.info_outline_rounded,
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: Text('about.title'.tr())),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          ProfileBodyPadding(
            children: [
              ProfileSectionCard(
                title: 'about.title'.tr(),
                subtitle: 'about.subtitle'.tr(),
                child: ProfileSubtleHint(
                  icon: Icons.shield_outlined,
                  text: 'about.disclaimer'.tr(
                    namedArgs: {'version': AppConfig.appVersion},
                  ),
                ),
              ),
              for (final section in sections)
                ProfileSectionCard(
                  title: section.title,
                  trailing: Icon(section.icon),
                  child: Text(section.body),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
