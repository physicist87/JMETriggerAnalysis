#ifndef JMETriggerAnalysis_RecoGenParticleCollectionContainer_h
#define JMETriggerAnalysis_RecoGenParticleCollectionContainer_h

#include <JMETriggerAnalysis/NTuplizers/interface/VRecoCandidateCollectionContainer.h>
#include <DataFormats/HepMCCandidate/interface/GenParticle.h>

class RecoGenParticleCollectionContainer
    : public VRecoCandidateCollectionContainer<reco::GenParticle> {
public:
  explicit RecoGenParticleCollectionContainer(const std::string&,
                                              const std::string&,
                                              const edm::EDGetToken&,
                                              const std::string& strCut = "",
                                              const bool orderByHighestPt = false);

  ~RecoGenParticleCollectionContainer() override {}

  void clear() override;
  void reserve(const size_t) override;
  void emplace_back(const reco::GenParticle&) override;

  void fillMotherDaughterIndices(
      const reco::GenParticleCollection&);
  // Basic particle information
  std::vector<int>& vec_pdgId() { return pdgId_; }
  std::vector<int>& vec_status() { return status_; }

  std::vector<float>& vec_pt() { return pt_; }
  std::vector<float>& vec_eta() { return eta_; }
  std::vector<float>& vec_phi() { return phi_; }
  std::vector<float>& vec_mass() { return mass_; }

  std::vector<float>& vec_vx() { return vx_; }
  std::vector<float>& vec_vy() { return vy_; }
  std::vector<float>& vec_vz() { return vz_; }

  // Generator status flags
  std::vector<unsigned int>& vec_statusFlags() { return statusFlags_; }

  // Mother/daughter indices
  std::vector<std::vector<int>>& vec_motherIndices() { return motherIndices_; }
  std::vector<std::vector<int>>& vec_daughterIndices() { return daughterIndices_; }

protected:
  std::vector<int> pdgId_;
  std::vector<int> status_;

  std::vector<float> pt_;
  std::vector<float> eta_;
  std::vector<float> phi_;
  std::vector<float> mass_;

  std::vector<float> vx_;
  std::vector<float> vy_;
  std::vector<float> vz_;

  std::vector<unsigned int> statusFlags_;

  std::vector<std::vector<int>> motherIndices_;
  std::vector<std::vector<int>> daughterIndices_;
};

#endif
