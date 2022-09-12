package it.constantinoit.promoproject.service;

import it.constantinoit.promoproject.model.Prospect;
import it.constantinoit.promoproject.repository.ProspectRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

@Service
public class ProspectService {

    @Autowired
    private ProspectRepository prospectRepository;

    public Boolean saveProspect(Prospect prospect) {
        prospectRepository.save(prospect);
        return Boolean.TRUE;
    }

}
