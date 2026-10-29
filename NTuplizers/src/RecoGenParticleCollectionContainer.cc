#include <JMETriggerAnalysis/NTuplizers/interface/RecoGenParticleCollectionContainer.h>

#include <stdexcept>
#include <unordered_map>

RecoGenParticleCollectionContainer::RecoGenParticleCollectionContainer(
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

void RecoGenParticleCollectionContainer::clear() {
  pdgId_.clear();
  status_.clear();
  statusFlags_.clear();

  pt_.clear();
  eta_.clear();
  phi_.clear();
  mass_.clear();

  vx_.clear();
  vy_.clear();
  vz_.clear();

  motherIndices_.clear();
  daughterIndices_.clear();
}

void RecoGenParticleCollectionContainer::reserve(const size_t vec_size) {
  pdgId_.reserve(vec_size);
  status_.reserve(vec_size);
  statusFlags_.reserve(vec_size);

  pt_.reserve(vec_size);
  eta_.reserve(vec_size);
  phi_.reserve(vec_size);
  mass_.reserve(vec_size);

  vx_.reserve(vec_size);
  vy_.reserve(vec_size);
  vz_.reserve(vec_size);

  motherIndices_.reserve(vec_size);
  daughterIndices_.reserve(vec_size);
}

void RecoGenParticleCollectionContainer::emplace_back(
    const reco::GenParticle& obj) {
  pdgId_.emplace_back(obj.pdgId());
  status_.emplace_back(obj.status());

  statusFlags_.emplace_back(
      static_cast<unsigned int>(
          obj.statusFlags().flags_.to_ulong()
      )
  );

  pt_.emplace_back(obj.pt());
  eta_.emplace_back(obj.eta());
  phi_.emplace_back(obj.phi());
  mass_.emplace_back(obj.mass());

  vx_.emplace_back(obj.vx());
  vy_.emplace_back(obj.vy());
  vz_.emplace_back(obj.vz());

  // Filled later using the complete reco::GenParticleCollection.
  motherIndices_.emplace_back();
  daughterIndices_.emplace_back();
}

void RecoGenParticleCollectionContainer::fillMotherDaughterIndices(
    const reco::GenParticleCollection& collection) {

  // Map the address of each GenParticle in the original collection
  // to its index in that collection.
  std::unordered_map<const reco::Candidate*, int> indexMap;
  indexMap.reserve(collection.size());

  for (size_t i = 0; i < collection.size(); ++i) {
    indexMap.emplace(
        static_cast<const reco::Candidate*>(&collection[i]),
        static_cast<int>(i)
    );
  }

  // At this stage we expect the ntuple container to contain the complete
  // GenParticle collection with the same ordering as the EDM collection.
  if (motherIndices_.size() != collection.size() ||
      daughterIndices_.size() != collection.size()) {
    throw std::runtime_error(
        "RecoGenParticleCollectionContainer::fillMotherDaughterIndices: "
        "stored collection size does not match input GenParticle collection size"
    );
  }

  for (size_t i = 0; i < collection.size(); ++i) {
    const auto& particle = collection[i];

    auto& mothers = motherIndices_[i];
    auto& daughters = daughterIndices_[i];

    mothers.clear();
    daughters.clear();

    mothers.reserve(particle.numberOfMothers());
    daughters.reserve(particle.numberOfDaughters());

    // Mothers
    for (size_t im = 0; im < particle.numberOfMothers(); ++im) {
      const reco::Candidate* mother = particle.mother(im);

      if (mother == nullptr) {
        continue;
      }

      const auto it = indexMap.find(mother);

      if (it != indexMap.end()) {
        mothers.emplace_back(it->second);
      }
    }

    // Daughters
    for (size_t id = 0; id < particle.numberOfDaughters(); ++id) {
      const reco::Candidate* daughter = particle.daughter(id);

      if (daughter == nullptr) {
        continue;
      }

      const auto it = indexMap.find(daughter);

      if (it != indexMap.end()) {
        daughters.emplace_back(it->second);
      }
    }
  }
}
