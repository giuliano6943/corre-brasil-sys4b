public with sharing class InscritosProvaController {

    // DTO: o objeto simples que viaja até o componente (só o que ele precisa mostrar)
    public class InscritoDto {
        @AuraEnabled public Id inscricaoId;
        @AuraEnabled public String corredor;
        @AuraEnabled public String situacao;
    }

    @AuraEnabled(cacheable=true)
    public static List<InscritoDto> getInscritos(Id provaId) {
        try {
            List<InscritoDto> resultado = new List<InscritoDto>();
            for (Inscricao__c insc : [
                SELECT Id, Situacao__c, Corredor__r.Name
                FROM Inscricao__c
                WHERE Prova__c = :provaId
                WITH USER_MODE
                ORDER BY Corredor__r.Name
                LIMIT 200
            ]) {
                InscritoDto dto = new InscritoDto();
                dto.inscricaoId = insc.Id;
                dto.corredor = insc.Corredor__r?.Name;
                dto.situacao = insc.Situacao__c;
                resultado.add(dto);
            }
            return resultado;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'getInscritos falhou: ' + e.getMessage());
            String mensagem = 'Não foi possível carregar as inscrições desta prova. Tente novamente em instantes.';
            AuraHandledException erro = new AuraHandledException(mensagem);
            erro.setMessage(mensagem);
            throw erro;
        }
    }
}