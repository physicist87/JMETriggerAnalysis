#include "JMETriggerAnalysis/NTuplizers/interface/RecoBasicJetCollectionContainer.h"

RecoBasicJetCollectionContainer::RecoBasicJetCollectionContainer(
    const std::string& name,
    const std::string& inputTagLabel,
    const edm::EDGetToken& token,
    const std::string& strCut,
    const bool orderByHighestPt)
    : VRecoCandidateCollectionContainer(
          name,
          inputTagLabel,
          token,
          strCut,
          orderByHighestPt) {}

void RecoBasicJetCollectionContainer::clear() {
  energy_.clear();
  pt_.clear();
  eta_.clear();
  phi_.clear();
  mass_.clear();

  jetArea_.clear();
  numberOfDaughters_.clear();
}

void RecoBasicJetCollectionContainer::reserve(const size_t vec_size) {
  energy_.reserve(vec_size);
  pt_.reserve(vec_size);
  eta_.reserve(vec_size);
  phi_.reserve(vec_size);
  mass_.reserve(vec_size);

  jetArea_.reserve(vec_size);
  numberOfDaughters_.reserve(vec_size);
}

void RecoBasicJetCollectionContainer::emplace_back(
    const reco::BasicJet& obj) {
  energy_.emplace_back(obj.energy());
  pt_.emplace_back(obj.pt());
  eta_.emplace_back(obj.eta());
  phi_.emplace_back(obj.phi());
  mass_.emplace_back(obj.mass());

  jetArea_.emplace_back(obj.jetArea());
  numberOfDaughters_.emplace_back(obj.numberOfDaughters());
}
