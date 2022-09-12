package it.constantinoit.promoproject.repository;

import it.constantinoit.promoproject.model.Prospect;
import org.springframework.data.mongodb.repository.MongoRepository;

public interface ProspectRepository extends MongoRepository<Prospect, String> {

}