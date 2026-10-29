#ifndef JMETriggerAnalysis_RecoBasicJetCollectionContainer_h
#define JMETriggerAnalysis_RecoBasicJetCollectionContainer_h

#include "JMETriggerAnalysis/NTuplizers/interface/VRecoCandidateCollectionContainer.h"
#include "DataFormats/JetReco/interface/BasicJet.h"

class RecoBasicJetCollectionContainer
    : public VRecoCandidateCollectionContainer<reco::BasicJet> {
public:
  explicit RecoBasicJetCollectionContainer(
      const std::string&,
      const std::string&,
      const edm::EDGetToken&,
      const std::string& strCut = "",
      const bool orderByHighestPt = false);

  ~RecoBasicJetCollectionContainer() override {}

  void clear() override;
  void reserve(const size_t) override;
  void emplace_back(const reco::BasicJet&) override;

  std::vector<float>& vec_energy() { return energy_; }
  std::vector<float>& vec_pt() { return pt_; }
  std::vector<float>& vec_eta() { return eta_; }
  std::vector<float>& vec_phi() { return phi_; }
  std::vector<float>& vec_mass() { return mass_; }

  std::vector<float>& vec_jetArea() { return jetArea_; }
  std::vector<uint>& vec_numberOfDaughters() {
    return numberOfDaughters_;
  }

protected:
  std::vector<float> energy_;
  std::vector<float> pt_;
  std::vector<float> eta_;
  std::vector<float> phi_;
  std::vector<float> mass_;

  std::vector<float> jetArea_;
  std::vector<uint> numberOfDaughters_;
};

#endif
